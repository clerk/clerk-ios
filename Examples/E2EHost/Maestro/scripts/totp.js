function base32Decode(value) {
  var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  var normalized = value.toUpperCase().replace(/[^A-Z2-7]/g, "");
  var bits = 0;
  var bitCount = 0;
  var bytes = [];

  for (var index = 0; index < normalized.length; index += 1) {
    bits = (bits << 5) | alphabet.indexOf(normalized.charAt(index));
    bitCount += 5;

    if (bitCount >= 8) {
      bitCount -= 8;
      bytes.push((bits >>> bitCount) & 0xff);
    }
  }

  return bytes;
}

function rotateLeft(value, count) {
  return ((value << count) | (value >>> (32 - count))) >>> 0;
}

function sha1(input) {
  var message = input.slice();
  var bitLength = message.length * 8;
  var highLength = Math.floor(bitLength / 0x100000000);
  var lowLength = bitLength >>> 0;

  message.push(0x80);
  while (message.length % 64 !== 56) {
    message.push(0);
  }

  for (var lengthShift = 24; lengthShift >= 0; lengthShift -= 8) {
    message.push((highLength >>> lengthShift) & 0xff);
  }
  for (var lowShift = 24; lowShift >= 0; lowShift -= 8) {
    message.push((lowLength >>> lowShift) & 0xff);
  }

  var h0 = 0x67452301;
  var h1 = 0xefcdab89;
  var h2 = 0x98badcfe;
  var h3 = 0x10325476;
  var h4 = 0xc3d2e1f0;

  for (var offset = 0; offset < message.length; offset += 64) {
    var words = [];
    var wordIndex;

    for (wordIndex = 0; wordIndex < 16; wordIndex += 1) {
      var byteIndex = offset + wordIndex * 4;
      words[wordIndex] = (
        (message[byteIndex] << 24)
        | (message[byteIndex + 1] << 16)
        | (message[byteIndex + 2] << 8)
        | message[byteIndex + 3]
      ) >>> 0;
    }

    for (wordIndex = 16; wordIndex < 80; wordIndex += 1) {
      words[wordIndex] = rotateLeft(
        words[wordIndex - 3] ^ words[wordIndex - 8] ^ words[wordIndex - 14] ^ words[wordIndex - 16],
        1
      );
    }

    var a = h0;
    var b = h1;
    var c = h2;
    var d = h3;
    var e = h4;

    for (wordIndex = 0; wordIndex < 80; wordIndex += 1) {
      var f;
      var k;

      if (wordIndex < 20) {
        f = (b & c) | ((~b) & d);
        k = 0x5a827999;
      } else if (wordIndex < 40) {
        f = b ^ c ^ d;
        k = 0x6ed9eba1;
      } else if (wordIndex < 60) {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8f1bbcdc;
      } else {
        f = b ^ c ^ d;
        k = 0xca62c1d6;
      }

      var temporary = (rotateLeft(a, 5) + f + e + k + words[wordIndex]) >>> 0;
      e = d;
      d = c;
      c = rotateLeft(b, 30);
      b = a;
      a = temporary;
    }

    h0 = (h0 + a) >>> 0;
    h1 = (h1 + b) >>> 0;
    h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0;
  }

  var digest = [];
  var hashWords = [h0, h1, h2, h3, h4];
  for (var hashIndex = 0; hashIndex < hashWords.length; hashIndex += 1) {
    for (var shift = 24; shift >= 0; shift -= 8) {
      digest.push((hashWords[hashIndex] >>> shift) & 0xff);
    }
  }

  return digest;
}

function hmacSha1(key, message) {
  var blockSize = 64;
  var normalizedKey = key.length > blockSize ? sha1(key) : key.slice();

  while (normalizedKey.length < blockSize) {
    normalizedKey.push(0);
  }

  var inner = [];
  var outer = [];
  for (var index = 0; index < blockSize; index += 1) {
    inner.push(normalizedKey[index] ^ 0x36);
    outer.push(normalizedKey[index] ^ 0x5c);
  }

  return sha1(outer.concat(sha1(inner.concat(message))));
}

function currentTotp(secret, unixSeconds) {
  var counter = Math.floor(unixSeconds / 30);
  var counterBytes = [];

  for (var index = 7; index >= 0; index -= 1) {
    counterBytes.push(Math.floor(counter / Math.pow(256, index)) & 0xff);
  }

  var digest = hmacSha1(base32Decode(secret), counterBytes);
  var offset = digest[digest.length - 1] & 0x0f;
  var binary = (
    ((digest[offset] & 0x7f) << 24)
    | ((digest[offset + 1] & 0xff) << 16)
    | ((digest[offset + 2] & 0xff) << 8)
    | (digest[offset + 3] & 0xff)
  ) >>> 0;
  var code = String(binary % 1000000);

  while (code.length < 6) {
    code = "0" + code;
  }

  return code;
}

var timestamp = typeof TOTP_TEST_TIME === "undefined"
  ? Math.floor(Date.now() / 1000)
  : Number(TOTP_TEST_TIME);
output.totp = currentTotp(maestro.copiedText, timestamp);
