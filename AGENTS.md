# Agent notes

This is Benedikt Frenzel's NixOS config. Upstream history belongs to Yurii; new work does not.

## Identity

Author and committer are Benedikt Frenzel <git@bfr.sh>. Sign commits and tags with the SSH key from the host 1Password vault (`op-ssh-sign`).

Do not set `GIT_AUTHOR_*`, `GIT_COMMITTER_*`, or jj `user.email` to Yurii or `yurii@goxore.com`. The wrapped `git` and `jj` packages already set the right identity. Do not hardcode `/home/yurii`.

`LICENSE` keeps `Copyright (c) 2023 Yurii M`. That notice stays with the upstream author.

## Commit messages

Subject: imperative, lowercase area prefix, same shape as existing history (`desktop:`, `git:`, `nixos:`).

Body only when the subject is not enough. After a blank line, add these trailers. Fill them from the current session, not from an older chat.

```
Assisted-by: OpenCode using xAI - Grok 4.7
Reviewed-by: Human
```

Shape: `Assisted-by: <Harness> using <Provider> - <Model>`.

- Harness is the agent app (`OpenCode`), not the model.
- Provider and model are the ones that actually wrote the change (`xAI`, `Grok 4.7`). Prefer the product name; the id `xai/grok-4.7` is fine if that is all the session exposes.
- `Reviewed-by: Human` means a person reviewed and tested the result. Add it only when that happened. Do not invent a name, and do not claim a review that did not happen.

Keep the trailers out of the subject line.
