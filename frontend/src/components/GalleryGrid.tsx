'use client';

import { useState } from 'react';
import GalleryCard from './GalleryCard';
import type { GalleryEntry } from '@/types';

interface GalleryGridProps {
  entries: GalleryEntry[];
}

export default function GalleryGrid({ entries }: GalleryGridProps) {
  const [selectedEntry, setSelectedEntry] = useState<GalleryEntry | null>(null);

  if (entries.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 px-6">
        <div className="mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-white/5 border border-white/10">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={1.5}
            strokeLinecap="round"
            strokeLinejoin="round"
            className="h-8 w-8 text-white/30"
          >
            <rect x="3" y="3" width="18" height="18" rx="2" />
            <circle cx="8.5" cy="8.5" r="1.5" />
            <path d="m21 15-5-5L5 21" />
          </svg>
        </div>
        <p className="text-white/50 text-sm mb-1">Aun no tienes sesiones</p>
        <p className="text-white/30 text-xs mb-6">Tus paisajes emocionales apareceran aqui</p>
        <a
          href="/session"
          className="rounded-full bg-white/10 px-6 py-2 text-sm text-white/80 border border-white/10 transition-colors hover:bg-white/15"
        >
          Comenzar primera sesion
        </a>
      </div>
    );
  }

  return (
    <>
      <div className="grid grid-cols-2 gap-3 p-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
        {entries.map((entry) => (
          <GalleryCard
            key={entry.sessionId}
            entry={entry}
            onClick={setSelectedEntry}
          />
        ))}
      </div>

      {/* Full-screen artwork viewer */}
      {selectedEntry && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 backdrop-blur-xl p-4"
          onClick={() => setSelectedEntry(null)}
          role="dialog"
          aria-modal="true"
        >
          <button
            className="absolute right-4 top-4 flex h-10 w-10 items-center justify-center rounded-full bg-white/10 border border-white/10 text-white/70 hover:bg-white/20 transition-colors"
            onClick={() => setSelectedEntry(null)}
            aria-label="Cerrar"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth={2}
              strokeLinecap="round"
              strokeLinejoin="round"
              className="h-5 w-5"
            >
              <path d="M18 6 6 18" />
              <path d="m6 6 12 12" />
            </svg>
          </button>

          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={selectedEntry.finalImageUrl}
            alt="Paisaje emocional"
            className="max-h-[80vh] max-w-full rounded-xl object-contain"
            onClick={(e) => e.stopPropagation()}
          />
        </div>
      )}
    </>
  );
}
