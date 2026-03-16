import type { WSMessageToServer } from '@/types';

type ConnectionState = 'disconnected' | 'connecting' | 'connected';

interface WebSocketClientOptions {
  onTextMessage: (data: string) => void;
  onBinaryMessage: (data: ArrayBuffer) => void;
  onStateChange: (state: ConnectionState) => void;
}

const MAX_BACKOFF_MS = 30000;
const INITIAL_BACKOFF_MS = 1000;

export class MirrorWebSocket {
  private ws: WebSocket | null = null;
  private url = '';
  private options: WebSocketClientOptions;
  private state: ConnectionState = 'disconnected';
  private shouldReconnect = false;
  private reconnectAttempt = 0;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(options: WebSocketClientOptions) {
    this.options = options;
  }

  get connectionState(): ConnectionState {
    return this.state;
  }

  get isConnected(): boolean {
    return this.state === 'connected';
  }

  connect(url: string): void {
    this.url = url;
    this.shouldReconnect = true;
    this.reconnectAttempt = 0;
    this.doConnect();
  }

  disconnect(): void {
    this.shouldReconnect = false;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.ws) {
      this.ws.onclose = null;
      this.ws.onerror = null;
      this.ws.onmessage = null;
      this.ws.onopen = null;
      this.ws.close();
      this.ws = null;
    }
    this.setState('disconnected');
  }

  sendBinary(data: ArrayBuffer): void {
    if (this.ws && this.state === 'connected') {
      this.ws.send(data);
    }
  }

  sendJSON(data: WSMessageToServer): void {
    if (this.ws && this.state === 'connected') {
      this.ws.send(JSON.stringify(data));
    }
  }

  private doConnect(): void {
    if (this.ws) {
      this.ws.onclose = null;
      this.ws.onerror = null;
      this.ws.close();
    }

    this.setState('connecting');

    try {
      this.ws = new WebSocket(this.url);
      this.ws.binaryType = 'arraybuffer';

      this.ws.onopen = () => {
        this.reconnectAttempt = 0;
        this.setState('connected');
      };

      this.ws.onmessage = (event: MessageEvent) => {
        if (event.data instanceof ArrayBuffer) {
          this.options.onBinaryMessage(event.data);
        } else if (typeof event.data === 'string') {
          this.options.onTextMessage(event.data);
        }
      };

      this.ws.onclose = () => {
        this.setState('disconnected');
        this.scheduleReconnect();
      };

      this.ws.onerror = () => {
        // onclose will fire after onerror, reconnect handled there
      };
    } catch {
      this.setState('disconnected');
      this.scheduleReconnect();
    }
  }

  private scheduleReconnect(): void {
    if (!this.shouldReconnect) return;

    const backoff = Math.min(
      INITIAL_BACKOFF_MS * Math.pow(2, this.reconnectAttempt),
      MAX_BACKOFF_MS
    );
    this.reconnectAttempt++;

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      if (this.shouldReconnect) {
        this.doConnect();
      }
    }, backoff);
  }

  private setState(newState: ConnectionState): void {
    if (this.state !== newState) {
      this.state = newState;
      this.options.onStateChange(newState);
    }
  }
}
