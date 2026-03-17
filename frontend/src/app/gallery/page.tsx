'use client';

import Link from 'next/link';
import GalleryGrid from '@/components/GalleryGrid';
import type { GalleryEntry } from '@/types';

// Mock data for MVP -- will be replaced with Firebase data
const MOCK_ENTRIES: GalleryEntry[] = [];

export default function GalleryPage() {
  return (
    <main className="relative min-h-dvh bg-[#0a0a1a] overflow-y-auto">
      {/* Header */}
      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-white/5 bg-[#0a0a1a]/80 px-4 py-3 backdrop-blur-xl safe-top">
        <Link
          href="/"
          className="flex h-10 w-10 items-center justify-center rounded-full bg-white/5 border border-white/10 transition-colors hover:bg-white/10"
          aria-label="Volver al inicio"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            className="h-4 w-4 text-white/70"
          >
            <path d="M19 12H5" />
            <path d="m12 19-7-7 7-7" />
          </svg>
        </Link>

        <h1 className="text-sm font-medium text-white/70 tracking-wide">
          Galería
        </h1>

        <Link
          href="/session"
          className="flex h-10 items-center gap-1.5 rounded-full bg-white/5 px-3 border border-white/10 transition-colors hover:bg-white/10"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            className="h-4 w-4 text-white/70"
          >
            <path d="M12 5v14" />
            <path d="M5 12h14" />
          </svg>
          <span className="text-xs text-white/60 hidden sm:inline">Nueva sesión</span>
        </Link>
      </header>

      {/* Gallery content */}
      <GalleryGrid entries={MOCK_ENTRIES} />
    </main>
  );
}
