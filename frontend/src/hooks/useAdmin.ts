'use client';

import { useCallback, useState } from 'react';
import { useAuth } from '@clerk/nextjs';
import { API_BASE_URL } from '@/lib/constants';
import type { AdminUser } from '@/types';

export function useAdmin() {
  const { getToken } = useAuth();
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchUsers = useCallback(
    async (limit = 100, offset = 0) => {
      setLoading(true);
      setError(null);
      try {
        const token = await getToken();
        const res = await fetch(
          `${API_BASE_URL}/api/admin/users?limit=${limit}&offset=${offset}`,
          { headers: { Authorization: `Bearer ${token}` } },
        );
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          throw new Error(body.detail ?? `Error ${res.status}`);
        }
        const data = await res.json();
        setUsers(data.users);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Error desconocido');
      } finally {
        setLoading(false);
      }
    },
    [getToken],
  );

  const updatePoints = useCallback(
    async (userId: string, points: number) => {
      const token = await getToken();
      const res = await fetch(
        `${API_BASE_URL}/api/admin/users/${userId}/points`,
        {
          method: 'PATCH',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ points }),
        },
      );
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.detail ?? `Error ${res.status}`);
      }
      // Update local state
      setUsers((prev) =>
        prev.map((u) => (u.id === userId ? { ...u, points } : u)),
      );
    },
    [getToken],
  );

  return { users, loading, error, fetchUsers, updatePoints };
}
