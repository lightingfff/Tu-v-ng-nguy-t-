import { cameraTop, height, viewportHeight, viewportWidth, width } from './world.js';

const vertex = `attribute vec2 position;
varying vec2 screen;
void main() {
  screen = vec2(position.x + 1.0, 1.0 - position.y) * 0.5;
  gl_Position = vec4(position, 0.0, 1.0);
}`;

const fragment = `precision highp float;
varying vec2 screen;
uniform sampler2D painting, material;
uniform vec4 view;
uniform vec2 size;
uniform float elapsed;
void main() {
  vec2 uv = (view.xy + screen * view.zw) / size;
  float farPlane = smoothstep(0.28, 0.44, uv.x) * (1.0 - smoothstep(0.70, 0.80, uv.x))
    * (1.0 - smoothstep(0.35, 0.49, uv.y));
  uv.x -= (view.x + view.z * 0.5 - size.x * 0.5) / size.x * farPlane * 0.045;
  vec3 mat = texture2D(material, uv).rgb;
  float wave = sin(uv.y * 641.0 + elapsed * 4.0 + uv.x * 29.0)
    + 0.40 * sin(uv.y * 887.0 - elapsed * 2.94 - uv.x * 54.0);
  vec3 color = texture2D(painting, uv + vec2(wave * 3.1, 0.48 * wave) / size * mat.b).rgb;
  float key = dot(mat.rg * 2.0 - 1.0, vec2(-0.82, -0.57));
  float canopy = max(1.0 - smoothstep(0.03, 0.29, uv.x), smoothstep(0.78, 0.97, uv.x));
  float paving = smoothstep(0.68, 0.735, uv.y) * (1.0 - smoothstep(0.75, 0.83, uv.y));
  float leaves = sin(uv.x * 97.0 + uv.y * 42.0 + sin(elapsed * 0.65))
    + 0.55 * sin(uv.x * 211.0 - uv.y * 123.0 - elapsed * 0.62);
  float shade = canopy * paving * smoothstep(-0.35, 0.75, leaves);
  color *= mix(vec3(1.0), vec3(0.83, 0.88, 0.94), shade);
  color += max(key, 0.0) * vec3(0.34, 0.26, 0.16) * (1.0 - shade);
  color *= 1.0 + min(key, 0.0) * 0.37;
  float glint = pow(clamp(wave * 0.75, 0.0, 1.0), 9.0) * mat.b;
  color += vec3(0.21, 0.15, 0.07) * glint * exp(-((uv.x - 0.525) * (uv.x - 0.525) / 0.0049));
  gl_FragColor = vec4(color, 1.0);
}`;

export function createTerrain(painting, material) {
  const canvas = document.createElement('canvas');
  canvas.width = viewportWidth;
  canvas.height = viewportHeight;
  const gl = canvas.getContext('webgl', { alpha: false, antialias: false, depth: false, failIfMajorPerformanceCaveat: true });
  if (!gl) return null;
  const program = gl.createProgram();
  for (const [kind, source] of [[gl.VERTEX_SHADER, vertex], [gl.FRAGMENT_SHADER, fragment]]) {
    const shader = gl.createShader(kind);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) return null;
    gl.attachShader(program, shader);
    gl.deleteShader(shader);
  }
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) return null;
  gl.useProgram(program);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 3,-1, -1,3]), gl.STATIC_DRAW);
  const position = gl.getAttribLocation(program, 'position');
  gl.enableVertexAttribArray(position);
  gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
  for (const [unit, name, bitmap] of [[0, 'painting', painting], [1, 'material', material]]) {
    gl.activeTexture(gl.TEXTURE0 + unit);
    gl.bindTexture(gl.TEXTURE_2D, gl.createTexture());
    for (const param of [gl.TEXTURE_MIN_FILTER, gl.TEXTURE_MAG_FILTER]) {
      gl.texParameteri(gl.TEXTURE_2D, param, gl.LINEAR);
    }
    for (const param of [gl.TEXTURE_WRAP_S, gl.TEXTURE_WRAP_T]) {
      gl.texParameteri(gl.TEXTURE_2D, param, gl.CLAMP_TO_EDGE);
    }
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, bitmap);
    gl.uniform1i(gl.getUniformLocation(program, name), unit);
  }
  gl.uniform2f(gl.getUniformLocation(program,'size'), width, height);
  const view = gl.getUniformLocation(program, 'view');
  const elapsed = gl.getUniformLocation(program, 'elapsed');
  return (ctx, camera, time) => {
    if (gl.isContextLost()) return false;
    gl.uniform4f(view, camera, cameraTop, viewportWidth, viewportHeight);
    gl.uniform1f(elapsed, time);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    ctx.drawImage(canvas, 0, 0);
    return true;
  };
}
