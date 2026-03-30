'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useUser } from '@clerk/nextjs';
import { useAdmin } from '@/hooks/useAdmin';

export default function AdminPage() {
  const router = useRouter();
  const { user, isLoaded } = useUser();
  const { users, loading, error, fetchUsers, updatePoints } = useAdmin();
  const [editingPoints, setEditingPoints] = useState<Record<string, string>>({});
  const [savingUser, setSavingUser] = useState<string | null>(null);

  const isAdmin = user?.publicMetadata?.role === 'admin';

  // Redirect non-admins
  useEffect(() => {
    if (isLoaded && (!user || !isAdmin)) {
      router.push('/');
    }
  }, [isLoaded, user, isAdmin, router]);

  // Fetch users on mount
  useEffect(() => {
    if (isLoaded && isAdmin) {
      fetchUsers();
    }
  }, [isLoaded, isAdmin, fetchUsers]);

  if (!isLoaded || !isAdmin) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-[#0a0a1a]">
        <div className="h-8 w-8 rounded-full border-2 border-white/10 border-t-white/40 animate-spin" />
      </main>
    );
  }

  const handleSave = async (userId: string) => {
    const raw = editingPoints[userId];
    if (raw === undefined) return;
    const points = parseInt(raw, 10);
    if (isNaN(points) || points < 0) return;

    setSavingUser(userId);
    try {
      await updatePoints(userId, points);
      setEditingPoints((prev) => {
        const next = { ...prev };
        delete next[userId];
        return next;
      });
    } catch {
      // Error is already shown via the hook
    } finally {
      setSavingUser(null);
    }
  };

  return (
    <main className="min-h-dvh bg-[#0a0a1a] px-4 py-8 sm:px-8">
      {/* Header */}
      <div className="mx-auto max-w-4xl">
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-light text-white/90">Panel de Administración</h1>
            <p className="mt-1 text-sm text-white/40">Gestionar puntos de usuarios</p>
          </div>
          <button
            onClick={() => router.push('/')}
            className="rounded-full bg-white/5 px-4 py-2 text-xs text-white/50 border border-white/10 transition-colors hover:bg-white/10"
          >
            Volver
          </button>
        </div>

        {/* Error */}
        {error && (
          <div className="mb-4 rounded-lg bg-red-500/10 border border-red-500/20 px-4 py-3 text-sm text-red-400">
            {error}
          </div>
        )}

        {/* Table */}
        <div className="overflow-x-auto rounded-xl border border-white/10 bg-white/[0.02]">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-white/10 text-xs uppercase tracking-wider text-white/30">
                <th className="px-4 py-3">Usuario</th>
                <th className="px-4 py-3">Email</th>
                <th className="px-4 py-3">Rol</th>
                <th className="px-4 py-3 text-center">Puntos</th>
                <th className="px-4 py-3 text-center">Acciones</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={5} className="px-4 py-8 text-center text-white/30">
                    Cargando usuarios...
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-4 py-8 text-center text-white/30">
                    No se encontraron usuarios
                  </td>
                </tr>
              ) : (
                users.map((u) => {
                  const isEditing = editingPoints[u.id] !== undefined;
                  const isSaving = savingUser === u.id;
                  return (
                    <tr key={u.id} className="border-b border-white/5 hover:bg-white/[0.02]">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          {u.image_url ? (
                            <img
                              src={u.image_url}
                              alt=""
                              className="h-8 w-8 rounded-full object-cover"
                            />
                          ) : (
                            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-xs text-white/50">
                              {(u.first_name?.[0] ?? u.email?.[0] ?? '?').toUpperCase()}
                            </div>
                          )}
                          <span className="text-white/70">
                            {[u.first_name, u.last_name].filter(Boolean).join(' ') || 'Sin nombre'}
                          </span>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-white/40">{u.email}</td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-block rounded-full px-2 py-0.5 text-xs ${
                            u.role === 'admin'
                              ? 'bg-indigo-500/20 text-indigo-400'
                              : 'bg-white/5 text-white/40'
                          }`}
                        >
                          {u.role}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-center">
                        {isEditing ? (
                          <input
                            type="number"
                            min={0}
                            max={10000}
                            value={editingPoints[u.id]}
                            onChange={(e) =>
                              setEditingPoints((prev) => ({
                                ...prev,
                                [u.id]: e.target.value,
                              }))
                            }
                            className="w-20 rounded bg-white/10 px-2 py-1 text-center text-sm text-white/90 border border-white/20 outline-none focus:border-indigo-500/50"
                            disabled={isSaving}
                          />
                        ) : (
                          <span className="font-mono text-white/70">{u.points}</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-center">
                        <div className="flex items-center justify-center gap-2">
                          {isEditing ? (
                            <>
                              <button
                                onClick={() => handleSave(u.id)}
                                disabled={isSaving}
                                className="rounded bg-indigo-500/20 px-3 py-1 text-xs text-indigo-400 transition-colors hover:bg-indigo-500/30 disabled:opacity-50"
                              >
                                {isSaving ? '...' : 'Guardar'}
                              </button>
                              <button
                                onClick={() =>
                                  setEditingPoints((prev) => {
                                    const next = { ...prev };
                                    delete next[u.id];
                                    return next;
                                  })
                                }
                                disabled={isSaving}
                                className="rounded bg-white/5 px-3 py-1 text-xs text-white/40 transition-colors hover:bg-white/10 disabled:opacity-50"
                              >
                                Cancelar
                              </button>
                            </>
                          ) : (
                            <button
                              onClick={() =>
                                setEditingPoints((prev) => ({
                                  ...prev,
                                  [u.id]: String(u.points),
                                }))
                              }
                              className="rounded bg-white/5 px-3 py-1 text-xs text-white/50 transition-colors hover:bg-white/10"
                            >
                              Editar
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </main>
  );
}
