'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useUser, useAuth } from '@clerk/nextjs';
import GalleryGrid from '@/components/GalleryGrid';
import type { GalleryEntry } from '@/types';

const API_BASE = process.env.NEXT_PUBLIC_WS_URL
  ? process.env.NEXT_PUBLIC_WS_URL.replace('wss://', 'https://').replace('ws://', 'http://').replace('/ws', '')
  : 'http://localhost:8080';

export default function GalleryPage() {
  const { user, isLoaded } = useUser();
  const { getToken } = useAuth();
  const [entries, setEntries] = useState<GalleryEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isLoaded || !user) {
      if (isLoaded) setLoading(false);
      return;
    }

    const loadGallery = async () => {
      try {
        const token = await getToken();
        const res = await fetch(`${API_BASE}/api/gallery/${user.id}`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });
        const data = await res.json();
        const gallery = (data.gallery ?? []).map((entry: Record<string, unknown>) => ({
          sessionId: entry.session_id as string ?? entry.gallery_id as string,
          date: new Date((entry.created_at as number) * 1000).toISOString(),
          emotions: (entry.emotional_journey as Array<{ emotion: string }> ?? []).map(
            (e: { emotion: string }) => e.emotion
          ),
          finalEmotion: entry.final_emotion as string ?? 'neutral',
          finalImageUrl: entry.final_image_url as string ?? '',
          thumbnailUrl: entry.thumbnail_url as string ?? '',
          imageCount: entry.image_count as number ?? 0,
          galleryId: entry.gallery_id as string,
        }));
        setEntries(gallery);
      } catch (err) {
        console.error('Failed to load gallery:', err);
      } finally {
        setLoading(false);
      }
    };
    loadGallery();
  }, [isLoaded, user, getToken]);

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
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <p className="text-white/40 text-sm">Cargando galería...</p>
        </div>
      ) : (
        <GalleryGrid entries={entries} />
      )}
    </main>
  );
}
