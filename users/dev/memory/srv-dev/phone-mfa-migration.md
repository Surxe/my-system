---
name: phone-mfa-migration
description: Checklist for safely moving MFA to a new phone (all 2FA lives in Microsoft Authenticator)
metadata:
  node_type: memory
  type: reference
  modified: 2026-09-19T00:00:00.000Z
---

All of Ethan's MFA lives in **Microsoft Authenticator** on **iOS** (~15 accounts
spanning a work identity, cloud, code/package registries, and consumer services).

**Backup model (corrected 2026-09-19):** As of Microsoft's ~Oct 2025 rollout, iOS
Authenticator has **no in-app cloud-backup toggle and no Microsoft-account requirement**
anymore — that's why there's no login/account/backup setting in the app (Ethan
unregistered his old school account; that's fine). Backup is now **automatic via
iCloud + iCloud Keychain, tied to the Apple ID**. It covers account names + TOTP
secrets for work/school, personal, and third-party accounts.

**So the real backup check is in iOS Settings, not the app:**
- Settings → [name] → iCloud → **iCloud Keychain / Passwords = ON**, and iCloud enabled (iOS 16+).
- If those are on, all accounts are already backed up.
- Restore = new iPhone on the **same Apple ID** auto-restores. The dependency is now
  **control of the Apple ID** (know its password; set up its recovery: trusted number /
  recovery key / recovery contact).

**If Ethan decides to get a new phone, before doing anything irreversible:**
1. **Record every account** the old phone's Authenticator lists (screenshot / write down all ~15).
2. **Check the password manager** for which accounts have saved recovery/backup codes;
   note the gaps. Package registries matter most (recovery codes are basically the
   only lifeline; no support reset).
3. Set up the new phone and **restore/re-add**, then **test that every account
   produces a working code** while the old phone is still alive.
4. **Do NOT wipe/discard/sell the old phone** until all accounts verified on the new one.
5. May need to **add secondary recovery methods** (passkey/hardware key, SMS/email
   fallback) for the most critical accounts so no single phone loss locks him out.

Also: the password-manager login itself is MFA-gated, so keep an **offline** way into
the manager (emergency kit / recovery key) — otherwise the backup codes are locked
behind the very thing they're meant to recover.

**Why:** Ethan is anxious about losing MFA access on an unplanned phone change and asked to persist this.
**How to apply:** surface this checklist when he mentions getting/replacing a phone or migrating Authenticator.
