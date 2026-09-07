(function () {
  var registry = new Map();

  function registryKey(kind, scope, id) {
    return String(kind) + ':' + String(scope || '') + ':' + String(id);
  }

  function fail(code, message) {
    throw JSON.stringify({
      kind: 'resolution',
      errors: [],
      code: code,
      message: message || code,
    });
  }

  function envelopeFrom(error) {
    if (typeof error === 'string') {
      try {
        return JSON.parse(error);
      } catch (parseError) {
        return { kind: 'javascript', errors: [], message: error };
      }
    }
    var errors = error && Array.isArray(error.errors) ? error.errors : [];
    var first = errors[0];
    var code = (first && first.code) || (error && error.code) || '';
    var message =
      (first && (first.long_message || first.message)) ||
      (error && error.message) ||
      String(error);
    var kind = 'javascript';
    if (errors.length) {
      kind = 'api';
    } else if (code === 'network_error' || (error && error.name === 'ClerkOfflineError')) {
      kind = 'offline';
    } else if (error && error.clerkRuntimeError) {
      kind = 'runtime';
    }
    return {
      kind: kind,
      errors: errors,
      clerkTraceId: (error && (error.clerk_trace_id || error.clerkTraceId)) || undefined,
      status: (error && error.status) || undefined,
      code: code || undefined,
      message: String(message),
    };
  }

  function findById(list, id) {
    if (!list) {
      return null;
    }
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].id === id) {
        return list[i];
      }
    }
    return null;
  }

  function remember(value) {
    if (!value || typeof value !== 'object') {
      return;
    }
    if (Array.isArray(value)) {
      value.forEach(remember);
      return;
    }
    if (typeof value.id === 'string' && Object.getPrototypeOf(value) !== Object.prototype) {
      var kind = value.constructor && value.constructor.name ? value.constructor.name : 'listed';
      registry.set(registryKey(kind, kind, value.id), value);
      registry.set(registryKey('listed', kind, value.id), value);
    }
    if (value.data) {
      remember(value.data);
    }
    if (value.organization) {
      remember(value.organization);
    }
  }

  function serialize(value) {
    if (value === undefined) {
      return null;
    }
    if (value === null || typeof value !== 'object') {
      return value;
    }
    if (value instanceof Date) {
      return value.getTime();
    }
    if (Array.isArray(value)) {
      return value.map(serialize);
    }
    remember(value);
    if (typeof value.__internal_toSnapshot === 'function') {
      return value.__internal_toSnapshot();
    }
    var out = {};
    var keys = Object.keys(value);
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      if (key === 'pathRoot') {
        continue;
      }
      out[key] = serialize(value[key]);
    }
    return out;
  }

  function hasMethod(obj, method) {
    return obj && typeof obj[method] === 'function';
  }

  async function resolve(receiver, method) {
    var clerk = globalThis.__clerkInstance;
    if (!clerk) {
      fail('not_loaded', 'Clerk is not loaded');
    }
    switch (receiver.kind) {
      case 'clerk':
        return clerk;
      case 'signIn':
        return clerk.client && clerk.client.signIn;
      case 'signUp':
        return clerk.client && clerk.client.signUp;
      case 'billing':
        return clerk.billing;
      case 'user':
        if (!clerk.user) {
          fail('no_user', 'No active user');
        }
        return clerk.user;
      case 'userResource': {
        if (!clerk.user) {
          fail('no_user', 'No active user');
        }
        var resource = findById(clerk.user[receiver.collection], receiver.id);
        if (!resource) {
          fail('not_found', 'User resource not found');
        }
        return resource;
      }
      case 'session': {
        var clientSession = clerk.client && findById(clerk.client.sessions, receiver.id);
        if (hasMethod(clientSession, method)) {
          return clientSession;
        }
        var listed =
          registry.get(registryKey('listed', 'sessionWithActivities', receiver.id)) ||
          registry.get(registryKey('SessionWithActivities', 'SessionWithActivities', receiver.id));
        if (hasMethod(listed, method)) {
          return listed;
        }
        if (clerk.user && typeof clerk.user.getSessions === 'function') {
          remember(await clerk.user.getSessions());
          listed =
            registry.get(registryKey('listed', 'sessionWithActivities', receiver.id)) ||
            registry.get(registryKey('SessionWithActivities', 'SessionWithActivities', receiver.id));
          if (hasMethod(listed, method)) {
            return listed;
          }
        }
        fail('not_found', 'Session not found');
        return null;
      }
      case 'organization': {
        var memberships = clerk.user && clerk.user.organizationMemberships;
        if (memberships) {
          for (var i = 0; i < memberships.length; i++) {
            var org = memberships[i] && memberships[i].organization;
            if (org && org.id === receiver.id) {
              return org;
            }
          }
        }
        var cached = registry.get(registryKey('listed', 'organization', receiver.id));
        if (cached) {
          return cached;
        }
        if (typeof clerk.getOrganization === 'function') {
          return await clerk.getOrganization(receiver.id);
        }
        fail('not_found', 'Organization not found');
        return null;
      }
      case 'listed': {
        var item = registry.get(registryKey('listed', receiver.scope || receiver.listedKind, receiver.id));
        if (!item) {
          fail('not_loaded', 'Listed resource was never serialized');
        }
        return item;
      }
      default:
        fail('not_found', 'Unknown receiver');
        return null;
    }
  }

  globalThis.__clerkNativeInvoke = async function (invocation) {
    var receiver = invocation.receiver;
    var method = invocation.method;
    var args = invocation.arguments || [];
    var target = await resolve(receiver, method);
    if (!hasMethod(target, method)) {
      fail('not_a_function', method + ' is not a function');
    }
    try {
      var value = await target[method].apply(target, args);
      if ((method === 'destroy' || method === 'delete') && (value === null || value === true || value === undefined)) {
        return { id: receiver.id, deleted: true };
      }
      return serialize(value);
    } catch (error) {
      throw JSON.stringify(envelopeFrom(error));
    }
  };

  globalThis.__clerkNativeInvokeClearRegistry = function () {
    registry.clear();
  };
})();
