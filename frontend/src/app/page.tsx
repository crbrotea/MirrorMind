'use client';

import Image from 'next/image';
import Link from 'next/link';

export default function LandingPage() {
  return (
    <main className="relative flex min-h-dvh flex-col items-center justify-center overflow-hidden px-6">
      {/* Animated gradient background */}
      <div className="absolute inset-0 -z-10">
        <div className="absolute inset-0 animate-gradient-flow bg-gradient-to-br from-[#0a0a1a] via-[#1a1a3e] to-[#0a0a1a] bg-[length:200%_200%]" />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_rgba(100,100,255,0.08)_0%,_transparent_70%)]" />

        {/* Floating orbs */}
        <div className="absolute left-1/4 top-1/3 h-64 w-64 rounded-full bg-purple-900/10 blur-3xl animate-ambient-shift" />
        <div
          className="absolute right-1/4 bottom-1/3 h-48 w-48 rounded-full bg-blue-900/10 blur-3xl animate-ambient-shift"
          style={{ animationDelay: '-5s' }}
        />
        <div
          className="absolute left-1/2 top-1/2 h-56 w-56 -translate-x-1/2 -translate-y-1/2 rounded-full bg-indigo-900/8 blur-3xl animate-ambient-shift"
          style={{ animationDelay: '-10s' }}
        />
      </div>

      {/* Content */}
      <div className="flex flex-col items-center text-center animate-float-up">
        {/* Logo mark */}
        <div className="mb-8">
          <Image
            src="/icon-192.png"
            alt="MirrorMind"
            width={80}
            height={80}
            className="drop-shadow-[0_0_20px_rgba(100,100,255,0.15)]"
            priority
          />
        </div>

        {/* Title */}
        <h1 className="mb-2 text-5xl font-extralight tracking-tight text-white sm:text-6xl">
          MirrorMind
        </h1>

        {/* Tagline */}
        <p className="mb-6 text-lg font-light tracking-wide text-white/50">
          Your Emotional Mirror
        </p>

        {/* Description */}
        <p className="mb-12 max-w-sm text-sm leading-relaxed text-white/35">
          Speak and watch your emotions transform into living landscapes.
          MirrorMind listens, reflects, and guides you to where you want to be.
        </p>

        {/* CTA */}
        <Link
          href="/session"
          className="group relative overflow-hidden rounded-full border border-white/15 bg-white/10 px-10 py-3.5 text-sm font-medium tracking-wide text-white/90 backdrop-blur-md transition-all duration-300 hover:bg-white/15 hover:border-white/25 hover:shadow-[0_0_30px_rgba(255,255,255,0.08)]"
        >
          <span className="relative z-10">Begin</span>
          <div className="absolute inset-0 -z-0 bg-gradient-to-r from-transparent via-white/5 to-transparent translate-x-[-200%] transition-transform duration-700 group-hover:translate-x-[200%]" />
        </Link>

        {/* Gallery link */}
        <Link
          href="/gallery"
          className="mt-6 text-xs text-white/25 transition-colors hover:text-white/45"
        >
          View session gallery
        </Link>
      </div>

      {/* Bottom subtle text */}
      <p className="absolute bottom-6 text-[10px] text-white/15 tracking-widest uppercase">
        Take a deep breath. Start here.
      </p>
    </main>
  );
}
