# CC Watch Launch Posts

> Ready-to-use posts for launch day. Edit as needed.

---

## Hacker News (Show HN)

**Title:** Show HN: CC Watch – Approve Claude Code changes from your Apple Watch

**Text:**
```
I built a watchOS app that lets you approve Claude Code tool calls from your wrist.

The problem: When Claude Code is running autonomously, it needs approval for file edits, bash commands, etc. I kept having to grab my laptop during meetings or while away from my desk.

The solution: CC Watch connects to Claude Code via a lightweight relay. When Claude needs approval, you get a push notification on your watch. Tap approve or reject - done.

Key features:
- Real-time push notifications
- Three modes: Normal (approve each), Auto-approve, Plan-only
- End-to-end encrypted (your code never touches our servers)
- Watch face complications for quick status

Technical stack:
- watchOS: SwiftUI + CryptoKit (Curve25519 + ChaChaPoly)
- CLI: Node.js + TweetNaCl for encryption
- Relay: Cloudflare Worker (just forwards encrypted blobs)

The relay is zero-knowledge - it only sees encrypted payloads and push tokens. Keys are exchanged during pairing and never leave your devices.

App Store: [link]
GitHub (CLI): [link]

Happy to answer questions about watchOS development or the E2E encryption architecture.
```

---

## Reddit - r/ClaudeAI

**Title:** I made an Apple Watch app to approve Claude Code changes on the go

**Text:**
```
Hey r/ClaudeAI!

I've been using Claude Code for a few months and kept running into the same problem: I'd start Claude on a task, walk away, and come back to find it waiting for approval on something.

So I built CC Watch - a watchOS app that sends push notifications when Claude needs approval. You can approve or reject right from your wrist.

**Features:**
- Push notifications for tool calls
- One-tap approve/reject
- Three modes (Normal, Auto-approve, Plan)
- E2E encrypted - the relay can't read your code

**How it works:**
1. Run `npx cc-watch` on your Mac
2. Pair with your Apple Watch
3. Start Claude Code normally
4. Get notifications on your watch when approval needed

It's been a game-changer for staying productive while not being chained to my desk.

App Store: [link]

Would love feedback from other Claude Code users!
```

---

## Reddit - r/programming

**Title:** Built an Apple Watch app for approving AI code changes - here's what I learned about watchOS development

**Text:**
```
I built CC Watch, an app that lets developers approve Claude Code (Anthropic's AI coding assistant) tool calls from their Apple Watch.

**The interesting technical bits:**

1. **E2E Encryption on watchOS**: Used CryptoKit with Curve25519 for key exchange and ChaChaPoly for symmetric encryption. The CLI uses TweetNaCl. Keys are exchanged during pairing - the relay server only sees encrypted blobs.

2. **Push Notification Architecture**: APNs for delivery, but the notification payload is encrypted. The watch decrypts locally to show the actual tool request.

3. **Pairing Flow**: Watch generates a 6-character code, you enter it in the CLI. During this exchange, both sides share public keys. Simple but secure.

4. **watchOS Constraints**:
   - No background WebSocket support (had to use push notifications)
   - Limited memory (had to be careful with payload sizes)
   - SwiftUI-only (no UIKit fallbacks)

The relay is a Cloudflare Worker - about 200 lines of TypeScript. Zero-knowledge by design.

App Store: [link]
GitHub: [link]

Happy to dive deeper into any part of the architecture.
```

---

## Reddit - r/apple

**Title:** Made a watchOS app for developers - CC Watch lets you approve AI code changes from your wrist

**Text:**
```
Built an Apple Watch app called CC Watch that connects to Claude Code (an AI coding assistant).

When the AI needs to edit a file or run a command, you get a notification on your watch. Tap approve or reject - no need to grab your phone or laptop.

**Why I built it:**
I kept starting AI coding tasks, walking to get coffee, and coming back to find Claude waiting for approval. Now I can approve from anywhere.

**watchOS features used:**
- Push notifications with custom actions
- Watch face complications
- SwiftUI with haptic feedback
- CryptoKit for E2E encryption

It's been really useful for staying productive during meetings or when away from my desk.

App Store: [link]
```

---

## Twitter/X

**Thread (5 tweets):**

**Tweet 1:**
```
Just shipped CC Watch - an Apple Watch app for Claude Code users.

Approve AI code changes from your wrist. No phone needed.

Here's why I built it and how it works:

[App Store link]

🧵 1/5
```

**Tweet 2:**
```
The problem:

Claude Code runs autonomously but needs approval for file edits, commands, etc.

I kept having to interrupt what I was doing to check my laptop.

Meetings, walks, deep work - all disrupted.

2/5
```

**Tweet 3:**
```
The solution:

CC Watch sends push notifications to your Apple Watch when Claude needs approval.

One tap to approve or reject.

Three modes:
- Normal (approve each action)
- Auto-approve (YOLO mode)
- Plan (only approve plans)

3/5
```

**Tweet 4:**
```
Security was non-negotiable:

- E2E encrypted (Curve25519 + ChaChaPoly)
- Zero-knowledge relay (only sees encrypted blobs)
- Keys exchanged during pairing
- Your code never touches our servers

4/5
```

**Tweet 5:**
```
Try it out:

1. Install from App Store
2. Run `npx cc-watch` on your Mac
3. Pair with the code on your watch
4. Start Claude Code normally

Link in bio. Happy to answer questions!

5/5
```

**Single tweet version:**
```
Shipped CC Watch - approve Claude Code changes from your Apple Watch.

- Push notifications when AI needs approval
- One-tap approve/reject
- E2E encrypted (your code stays private)
- Works while away from your desk

Perfect for staying productive without being chained to your laptop.

[link]
```

---

## LinkedIn

**Post:**
```
Excited to announce CC Watch - now available on the App Store!

CC Watch is a companion app for Claude Code that lets developers approve AI-assisted code changes directly from their Apple Watch.

The Problem:
AI coding assistants like Claude Code are incredibly powerful, but they need human approval for sensitive operations. This creates a productivity bottleneck - you have to stay near your computer or interrupt what you're doing to check on progress.

The Solution:
CC Watch sends push notifications to your Apple Watch when Claude needs approval. Review the request and tap to approve or reject - all from your wrist.

Key Features:
- Real-time push notifications
- One-tap approve/reject workflow
- Three operating modes for different trust levels
- End-to-end encryption (zero-knowledge architecture)
- Watch face complications for status at a glance

Technical Highlights:
Built with SwiftUI and CryptoKit for watchOS, with a lightweight Cloudflare Worker relay. The entire system is E2E encrypted - the relay only forwards encrypted payloads it cannot read.

This has been a passion project born from my own frustration with the approve-wait-approve cycle. Now I can start a coding task, walk to a meeting, and approve changes along the way.

Available now on the App Store.

#watchOS #SwiftUI #AI #DeveloperTools #ClaudeCode #Anthropic
```

---

## ProductHunt (save for later)

**Tagline:** Approve AI code changes from your Apple Watch

**Description:**
```
CC Watch connects your Apple Watch to Claude Code, letting you approve AI-assisted code changes on the go.

When Claude needs to edit a file or run a command, you get a push notification. Tap approve or reject - done.

Features:
- Real-time push notifications
- One-tap approval workflow
- Three modes: Normal, Auto-approve, Plan
- E2E encrypted (zero-knowledge server)
- Watch face complications

Built for developers who use Claude Code but don't want to be chained to their laptop.
```

**Maker Comment:**
```
Hey Product Hunt!

I built CC Watch because I kept getting interrupted by Claude Code approval requests.

The AI would be humming along, then stop and wait for me to approve a file edit - except I was in a meeting, or getting coffee, or just away from my desk.

Now I get a notification on my watch, tap approve, and Claude keeps working. It's been a game-changer for my productivity.

The whole system is E2E encrypted. The relay server only sees encrypted blobs - it can't read your code or even know what tool Claude is trying to use.

Would love your feedback!
```

---

*Created: 2026-01-21*
*Update links before posting*
