export class RequestPolicyError extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}
const MAX_BODY = 4 * 1024 * 1024;
const MAX_TEXT = 32000;
function reject(message) { throw new RequestPolicyError(message); }
function object(value) { return value !== null && typeof value === 'object' && !Array.isArray(value); }
function keys(value, allowed) {
  if (!object(value) || Object.keys(value).some(key => !allowed.includes(key))) reject('Unsupported request fields.');
}

export async function validatedBody(request, bucket) {
  if (new URL(request.url).search) reject('Query parameters are not supported.');
  if ((request.headers.get('Content-Type') ?? '').split(';')[0].trim().toLowerCase() !== 'application/json') {
    throw new RequestPolicyError('Content-Type must be application/json.', 415);
  }
  if (request.headers.has('Content-Encoding')) reject('Encoded request bodies are not supported.');
  if (Number(request.headers.get('Content-Length')) > MAX_BODY) throw new RequestPolicyError('Request is too large.', 413);
  const reader = request.body?.getReader();
  if (!reader) reject('A JSON body is required.');
  let size = 0; const chunks = [];
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BODY) {
        await reader.cancel();
        throw new RequestPolicyError('Request is too large.', 413);
      }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  let body;
  try { body = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); }
  catch { reject('Invalid JSON.'); }
  if (bucket === 'image') {
    keys(body, ['model', 'prompt', 'n', 'response_format']);
    if (body.model !== 'grok-imagine-image-quality') reject('Unsupported image model.');
    if (typeof body.prompt !== 'string' || !body.prompt.trim() || body.prompt.length > 8000) reject('Invalid image prompt.');
    if (body.n !== undefined && body.n !== 1) reject('Only one image is allowed per request.');
    if (body.response_format !== undefined && body.response_format !== 'url') reject('Unsupported image response format.');
    return JSON.stringify({ ...body, n: 1, response_format: 'url' });
  }
  keys(body, ['model', 'messages', 'max_tokens', 'temperature', 'stream']);
  if (!['grok-3-mini', 'grok-4.3'].includes(body.model)) reject('Unsupported chat model.');
  if (body.max_tokens !== undefined && (!Number.isInteger(body.max_tokens) || body.max_tokens < 1 || body.max_tokens > 4096)) reject('max_tokens must be between 1 and 4096.');
  if (body.temperature !== undefined && (typeof body.temperature !== 'number' || body.temperature < 0 || body.temperature > 2)) reject('Invalid temperature.');
  if (body.stream !== undefined && typeof body.stream !== 'boolean') reject('Invalid stream flag.');
  if (!Array.isArray(body.messages) || body.messages.length < 1 || body.messages.length > 64) reject('Provide 1 to 64 messages.');
  let textSize = 0; let images = 0;
  for (const message of body.messages) {
    keys(message, ['role', 'content']);
    if (!['system', 'user', 'assistant'].includes(message.role)) reject('Unsupported message role.');
    if (typeof message.content === 'string') { textSize += message.content.length; continue; }
    if (message.role !== 'user' || !Array.isArray(message.content) || !message.content.length || message.content.length > 8) reject('Invalid message content.');
    for (const part of message.content) {
      if (part?.type === 'text') {
        keys(part, ['type', 'text']);
        if (typeof part.text !== 'string') reject('Invalid text content.');
        textSize += part.text.length;
      } else if (part?.type === 'image_url') {
        keys(part, ['type', 'image_url']); keys(part.image_url, ['url']);
        if (body.model !== 'grok-4.3' || ++images > 1 || typeof part.image_url.url !== 'string' ||
            !/^data:image\/jpeg;base64,[A-Za-z0-9+/]+={0,2}$/.test(part.image_url.url)) reject('Only one embedded JPEG is supported for vision.');
      } else reject('Unsupported content type.');
    }
  }
  if (textSize > MAX_TEXT) reject('Message text is too long.');
  return JSON.stringify({ ...body, max_tokens: body.max_tokens ?? 1024 });
}
