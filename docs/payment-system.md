# MirrorMind - Sistema de Pagos

## Context

MirrorMind actualmente es una app gratuita sin monetizacion. Se necesita implementar un sistema de pagos con multiples niveles de suscripcion, compras unicas (packs de creditos), y enforcement de limites de uso. El objetivo es monetizar el producto sin degradar la experiencia del usuario free, ofreciendo valor incremental claro en cada tier.

**Stack actual**: Next.js 16 + FastAPI + Clerk Auth + Firestore + Gemini APIs
**Proveedor de pagos**: Stripe (integracion directa, no via Clerk billing)

---

## 1. Tiers de Precio

### Free (Gratis)
| Feature | Limite |
|---------|--------|
| Sesiones por mes | 3 |
| Imagenes por sesion | 2 |
| Duracion max sesion | 10 min |
| Resolucion imagen | 1K (1024x576) |
| Descarga HD de arte | No |
| Ejercicios respiracion | Solo "box breathing" |
| Retencion galeria | 30 dias |
| Creditos incluidos | 0 |

### Pro ($9.99/mes o $99/ano)
| Feature | Limite |
|---------|--------|
| Sesiones por mes | 30 |
| Imagenes por sesion | 5 |
| Duracion max sesion | 30 min |
| Resolucion imagen | 1K |
| Descarga HD de arte | Si |
| Ejercicios respiracion | Todos (box, calm, physiological sigh) |
| Retencion galeria | 1 ano |
| Creditos incluidos | 0 |

### Premium ($19.99/mes o $199/ano)
| Feature | Limite |
|---------|--------|
| Sesiones por mes | Ilimitadas |
| Imagenes por sesion | Ilimitadas |
| Duracion max sesion | 60 min |
| Resolucion imagen | 2K |
| Descarga HD de arte | Si |
| Ejercicios respiracion | Todos |
| Retencion galeria | Para siempre |
| Creditos incluidos | 0 |

### Packs de Creditos (compra unica, cualquier tier)
- **10 creditos**: $4.99
- **25 creditos**: $9.99
- 1 credito = 1 sesion adicional mas alla del limite mensual
- Los creditos no expiran

---

## 2. Schema de Base de Datos (Firestore)

### Coleccion `subscriptions` (doc ID = user_id)
```json
{
  "user_id": "string",
  "stripe_customer_id": "string",
  "stripe_subscription_id": "string | null",
  "plan": "free | pro | premium",
  "status": "active | canceled | past_due | trialing",
  "current_period_start": "timestamp",
  "current_period_end": "timestamp",
  "cancel_at_period_end": "boolean",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```

### Coleccion `usage` (doc ID = `{user_id}_{YYYY-MM}`)
```json
{
  "user_id": "string",
  "period": "string (e.g. 2026-03)",
  "sessions_used": "number",
  "images_generated": "number",
  "total_session_seconds": "number",
  "credits_used": "number",
  "last_session_at": "timestamp"
}
```

### Coleccion `credits` (doc ID = user_id)
```json
{
  "user_id": "string",
  "balance": "number",
  "lifetime_purchased": "number",
  "updated_at": "timestamp"
}
```

### Coleccion `payment_history` (doc ID = auto)
```json
{
  "user_id": "string",
  "stripe_payment_intent_id": "string",
  "amount": "number",
  "currency": "string",
  "type": "subscription | credit_pack",
  "description": "string",
  "status": "succeeded | failed | refunded",
  "created_at": "timestamp"
}
```

---

## 3. Endpoints API (Backend)

### Nuevos REST endpoints
| Metodo | Ruta | Auth | Descripcion |
|--------|------|------|-------------|
| `POST` | `/api/billing/checkout` | Clerk JWT | Crea Stripe Checkout session (suscripcion) |
| `POST` | `/api/billing/portal` | Clerk JWT | Crea Stripe Customer Portal session |
| `GET` | `/api/billing/subscription/{user_id}` | Clerk JWT | Estado de suscripcion + uso actual |
| `GET` | `/api/billing/credits/{user_id}` | Clerk JWT | Balance de creditos |
| `POST` | `/api/billing/credits/purchase` | Clerk JWT | Compra pack de creditos |
| `POST` | `/api/stripe/webhook` | Stripe signature | Webhook handler (sin auth JWT) |

### Nuevos mensajes WebSocket (Server -> Client)
- `{"type": "quota_exceeded", "resource": "session"|"image", "message": "..."}` -- cuando se alcanza un limite
- `{"type": "usage_update", "imagesGenerated": N, "imagesLimit": N|null}` -- despues de cada imagen generada

---

## 4. Archivos a Crear

### Backend
| Archivo | Descripcion |
|---------|-------------|
| `/backend/mirror_mind/billing.py` | Servicio core: plan limits, quota checks, usage recording, credit ops. Cache in-memory (60s TTL) |
| `/backend/mirror_mind/stripe_service.py` | Integracion Stripe: checkout, portal, webhook handling |

### Frontend
| Archivo | Descripcion |
|---------|-------------|
| `/frontend/src/app/pricing/page.tsx` | Pagina de precios con 3 cards, toggle mensual/anual |
| `/frontend/src/app/billing/page.tsx` | Dashboard de facturacion: plan actual, uso, historial |
| `/frontend/src/hooks/useSubscription.ts` | Hook: fetch subscription + usage, expone `canStartSession`, `imagesRemaining` |
| `/frontend/src/components/UpgradePrompt.tsx` | Modal cuando se alcanza un limite |
| `/frontend/src/components/UsageMeter.tsx` | Barra de progreso de uso (sesiones/imagenes) |
| `/frontend/src/lib/billing-api.ts` | Cliente API para endpoints de billing |

---

## 5. Archivos a Modificar

### Backend

**`/backend/main.py`**
- Agregar quota check antes de `ws.accept()` en `websocket_endpoint`
- Reemplazar `MAX_SESSION_DURATION_SECONDS` hardcodeado por el limite del plan
- Agregar image cap enforcement en `deliver_images` loop
- Agregar `record_session_usage()` en session cleanup
- Agregar todos los nuevos REST endpoints de billing
- Agregar `POST` a `allow_methods` en CORS

**`/backend/mirror_mind/config.py`**
- Agregar variables de entorno Stripe: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, price IDs

**`/backend/mirror_mind/agent.py`**
- `analyze_and_generate_art`: verificar image cap antes de generar, usar image size del plan
- `get_breathing_pattern`: filtrar tecnicas segun plan del usuario

**`/backend/pyproject.toml`**
- Agregar `stripe~=12.0.0`

### Frontend

**`/frontend/src/middleware.ts`**
- Agregar `/billing(.*)` como ruta protegida

**`/frontend/src/types/index.ts`**
- Agregar tipos: `PlanTier`, `Subscription`, `UsageData`, `PlanLimits`
- Agregar variantes WebSocket: `quota_exceeded`, `usage_update`

**`/frontend/src/hooks/useMirrorMind.ts`**
- Manejar mensajes `quota_exceeded` y `usage_update`

**`/frontend/src/app/session/page.tsx`**
- Verificar suscripcion antes de conectar WebSocket
- Mostrar `UpgradePrompt` cuando se recibe `quota_exceeded`
- Agregar `UsageMeter` al header

**`/frontend/src/app/page.tsx`**
- Agregar link a `/pricing` en la navegacion
- Banner sutil de upgrade para usuarios free

**`/frontend/package.json`**
- Agregar `@stripe/stripe-js`

---

## 6. Secuencia de Implementacion

### Fase 1 -- Fundacion Backend
1. Agregar `stripe` a dependencias
2. Crear `billing.py` (plan limits, quota checks, usage tracking)
3. Crear `stripe_service.py` (checkout, portal, webhooks)
4. Agregar config vars a `config.py`
5. Agregar endpoints REST de billing a `main.py`

### Fase 2 -- Enforcement Backend
6. Quota check en WebSocket antes de accept
7. Image cap en `deliver_images` loop
8. Image cap awareness en `analyze_and_generate_art`
9. Usage recording en session cleanup
10. Breathing technique filtering por plan

### Fase 3 -- Frontend Pages
11. Agregar tipos a `types/index.ts`
12. Crear `billing-api.ts`
13. Crear `useSubscription.ts`
14. Crear pagina `/pricing`
15. Crear pagina `/billing`
16. Crear `UpgradePrompt` y `UsageMeter`

### Fase 4 -- Integracion Frontend
17. Actualizar middleware para nuevas rutas
18. Check de suscripcion en session page
19. Manejar nuevos mensajes WS en `useMirrorMind.ts`
20. Links de pricing en landing page

### Fase 5 -- Infraestructura Stripe
21. Crear productos y precios en Stripe Dashboard
22. Configurar webhook endpoint apuntando al backend Cloud Run
23. Configurar env vars en Cloud Run y Vercel
24. Test E2E del flujo completo

---

## 7. Flujo de Enforcement

```
Usuario inicia sesion
  -> Backend: check_session_quota(user_id)
    -> Lee subscription de Firestore (cache 60s)
    -> Lee usage del mes actual
    -> Si sessions_used < limit O tiene creditos -> PERMITIR
    -> Si sessions_used >= limit Y sin creditos -> RECHAZAR (ws.close 4003)

Durante sesion:
  -> Agent llama analyze_and_generate_art
    -> Backend verifica images_generated < images_per_session
    -> Si OK -> genera imagen, envia usage_update
    -> Si limite -> envia quota_exceeded, agent informa al usuario

Fin de sesion:
  -> record_session_usage(user_id, duration, images)
  -> Incrementa contadores en Firestore
```

---

## 8. Decisiones de Diseno

- **Enforcement en backend, no solo frontend**: El WebSocket consume recursos reales (Gemini API). El backend es el gatekeeper. Frontend solo muestra UX.
- **Firestore como cache de estado de billing (no Stripe como source of truth en cada request)**: Stripe se sincroniza via webhooks. Cache in-memory de 60s reduce lecturas Firestore durante sesiones activas.
- **Creditos como add-on, no modelo primario**: Suscripcion es mas simple. Creditos permiten flexibilidad sin complejidad de metering puro.
- **Stripe directo (no Clerk billing)**: Control total sobre pricing, usage metering y webhook handling sin depender del roadmap de Clerk.
- **Webhooks en backend Cloud Run (no Next.js API routes)**: Cloud Run tiene URL estable, sin cold starts ni timeout de 10s de Vercel serverless.

---

## 9. Verificacion

- **Unit tests**: Tests para `billing.py` (quota checks con diferentes planes/usos)
- **Integration tests**: Test webhook handler con payloads de Stripe (usar `stripe-mock`)
- **E2E manual**:
  1. Usuario free: verificar que se bloquea la 4ta sesion del mes
  2. Compra Pro: verificar checkout -> webhook -> acceso ampliado
  3. Image cap: verificar que free user recibe `quota_exceeded` despues de 2 imagenes
  4. Credits: comprar pack, verificar que permite sesion extra
  5. Portal: verificar que el usuario puede cancelar/cambiar plan desde Stripe Portal
- **Stripe CLI**: `stripe listen --forward-to localhost:8080/api/stripe/webhook` para testing local
