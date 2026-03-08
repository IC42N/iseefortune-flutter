# ISeeFortune Mobile (Flutter)

**ISeeFortune** is a mobile application for interacting with the
ISeeFortune prediction game on the Solana blockchain.

The game derives outcomes from **public, finalized Solana blockchain
data**, ensuring results are deterministic, transparent, and
independently verifiable.

------------------------------------------------------------------------

## Overview

ISeeFortune allows players to participate in an epoch‑based prediction
game where users:

-   Choose a number
-   Contribute conviction to a shared pot
-   Compete for a proportional payout if their prediction matches the
    winning number

All results are derived from immutable on‑chain data.

------------------------------------------------------------------------

## Key Principles

-   **Trustless** -- No private randomness or oracle manipulation\
-   **Deterministic** -- Outcomes derived directly from Solana
    blockchain data\
-   **Verifiable** -- Anyone can independently reproduce results\
-   **Transparent** -- Game state and results are publicly auditable

------------------------------------------------------------------------

## How the Winning Number Works

When an epoch ends:

1.  The **final slot** of the epoch is obtained.
2.  The **finalized blockhash** from that slot is retrieved.
3.  The slot and blockhash are combined.
4.  The data is hashed using **SHA‑256**.
5.  The resulting 32 bytes are summed.
6.  The total modulo **10** determines the winning number.

This ensures that:

-   No party can influence the outcome.
-   Anyone can recompute the result independently.

------------------------------------------------------------------------

## Mobile App Features

-   Connect to Solana wallets using **Mobile Wallet Adapter**
-   Submit predictions directly from mobile
-   View live epoch countdowns
-   Track prediction history
-   Verify results independently

------------------------------------------------------------------------

## Technology Stack

-   **Flutter**
-   **Solana Mobile Wallet Adapter (MWA)**
-   **Solana RPC**
-   **Anchor Program (on-chain game logic)**

------------------------------------------------------------------------

## Project Structure

    lib/
      ui/
      models/
      solana/
      services/
      utils/

    android/
    ios/
    web/

------------------------------------------------------------------------

## Getting Started

### 1. Install Flutter

https://docs.flutter.dev/get-started/install

### 2. Clone the Repository

    git clone https://github.com/IC42N/iseefortune-mobile.git
    cd iseefortune-mobile

### 3. Install Dependencies

    flutter pub get

### 4. Run the App

    flutter run

------------------------------------------------------------------------

## Verifying Results

The winning number can be independently verified using the public
verifier tools:

-   https://verify.iseefortune.com

Example verifier implementations are available in:

-   TypeScript
-   Rust

------------------------------------------------------------------------

## Security

If you discover a vulnerability, please report it responsibly.

Security policy:
https://github.com/IC42N/iseefortune-anchor/blob/main/SECURITY.md

------------------------------------------------------------------------

## License

MIT License

------------------------------------------------------------------------

Built with transparency and verifiability in mind.
