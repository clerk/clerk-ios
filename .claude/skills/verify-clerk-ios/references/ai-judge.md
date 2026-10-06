# AI judge

e2e's `agent.assert` can judge a visual claim that a selector cannot check. The judge is off, and golden specs never use it. Without a model in the config, any agent step fails.

To try it in an explored spec:

1. Install `ai` and `@ai-sdk/openai` with `npm i -D ai @ai-sdk/openai` in `.claude/skills/verify-clerk-ios`.
2. Sign in to a ChatGPT subscription with `npx e2e login openai`.
3. Set `VERIFY_JUDGE_MODEL=chatgpt:<model-id>`. `npx e2e models` lists the model ids.

Only then does `e2e.config.ts` set `agents.default.model`. A value that is not `chatgpt:<model-id>` is a usage error.
