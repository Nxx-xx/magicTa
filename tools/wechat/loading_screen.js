// Pure Canvas 2D renderer shared by the native loader and its visual preview.
export function loadingLayout(width, height, safeArea = {}) {
  const bottom = Math.max(0, height - (Number(safeArea.bottom) || height));
  const top = Math.max(0, Number(safeArea.top) || 0);
  const scale = Math.min(width / 540, height / 960);
  const panelWidth = Math.min(width * 0.77, 430 * scale);
  const barY = Math.min(height * 0.875, height - bottom - 72 * scale);
  return { scale, top, bottom, barX: (width - panelWidth) / 2, barY, barWidth: panelWidth };
}

function diamond(ctx, x, y, radius) {
  ctx.beginPath();
  ctx.moveTo(x, y - radius); ctx.lineTo(x + radius, y);
  ctx.lineTo(x, y + radius); ctx.lineTo(x - radius, y);
  ctx.closePath(); ctx.stroke();
}

export function drawLoadingScreen(ctx, image, width, height, progress, options = {}) {
  const layout = loadingLayout(width, height, options.safeArea);
  const { scale: s, top, barX: x, barY: y, barWidth: w } = layout;
  const pct = Math.max(0, Math.min(100, Number(progress) || 0));
  ctx.save();
  ctx.fillStyle = '#06131b'; ctx.fillRect(0, 0, width, height);
  // Fit the whole painting (including its title) on wide devices. On tall
  // phones extend the dark base, never crop off the title or stretch the art.
  if (image && image.width > 0 && image.height > 0) {
    const fit = Math.min(width / image.width, height / image.height);
    const iw = image.width * fit, ih = image.height * fit;
    // The painting already reserves sky above the title. Keep that sky behind
    // the status bar instead of introducing a solid rectangular top strip.
    ctx.drawImage(image, (width - iw) / 2, 0, iw, ih);
    const fade = ctx.createLinearGradient(0, ih * 0.90, 0, ih);
    fade.addColorStop(0, 'rgba(6,19,27,0)'); fade.addColorStop(1, '#06131b');
    ctx.fillStyle = fade; ctx.fillRect(0, ih * 0.90, width, ih * 0.10 + 1);
  } else {
    ctx.textAlign = 'center'; ctx.fillStyle = '#f3dcad';
    ctx.font = `${64 * s}px serif`; ctx.fillText('塔境', width / 2, top + height * 0.21);
    ctx.font = `${18 * s}px serif`; ctx.fillText('公主救援记', width / 2, top + height * 0.26);
  }
  const shade = ctx.createLinearGradient(0, y - 105 * s, 0, height);
  shade.addColorStop(0, 'rgba(6,19,27,0)'); shade.addColorStop(0.55, 'rgba(6,19,27,0.66)');
  shade.addColorStop(1, '#06131b'); ctx.fillStyle = shade;
  ctx.fillRect(0, y - 105 * s, width, height - y + 105 * s);
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillStyle = '#eee0c1'; ctx.font = `${18 * s}px serif`;
  ctx.fillText(options.failed ? '塔境暂未开启' : '正在唤醒塔境…', width / 2, y - 59 * s);
  ctx.font = `${27 * s}px Georgia, serif`;
  ctx.fillText(`${Math.floor(pct)}%`, width / 2, y - 25 * s);
  const barH = 7 * s, bevel = 4 * s;
  ctx.beginPath(); ctx.moveTo(x + bevel, y - barH / 2);
  ctx.lineTo(x + w - bevel, y - barH / 2); ctx.lineTo(x + w, y);
  ctx.lineTo(x + w - bevel, y + barH / 2); ctx.lineTo(x + bevel, y + barH / 2);
  ctx.lineTo(x, y); ctx.closePath();
  ctx.fillStyle = '#10232a'; ctx.fill(); ctx.strokeStyle = '#c7a86c'; ctx.lineWidth = s; ctx.stroke();
  const fillW = (w - 5 * s) * pct / 100;
  if (fillW > 0) {
    const gold = ctx.createLinearGradient(x, y, x + w, y);
    gold.addColorStop(0, '#b58b4e'); gold.addColorStop(1, '#ffe5a3');
    ctx.fillStyle = gold; ctx.fillRect(x + 2.5 * s, y - 1.8 * s, fillW, 3.6 * s);
    if (!options.failed) {
      const end = x + 2.5 * s + fillW;
      const pulse = 0.75 + Math.sin((options.time || 0) / 650) * 0.25;
      const glow = ctx.createRadialGradient(end, y, 0, end, y, 12 * s);
      glow.addColorStop(0, `rgba(255,227,159,${pulse})`); glow.addColorStop(1, 'rgba(255,214,138,0)');
      ctx.fillStyle = glow; ctx.fillRect(end - 12 * s, y - 12 * s, 24 * s, 24 * s);
      ctx.strokeStyle = '#fff2cf'; ctx.beginPath();
      ctx.moveTo(end, y - 6 * s); ctx.lineTo(end, y + 6 * s); ctx.stroke();
    }
  }
  ctx.strokeStyle = '#c7a86c'; diamond(ctx, x - 9 * s, y, 3.5 * s); diamond(ctx, x + w + 9 * s, y, 3.5 * s);
  ctx.fillStyle = '#c9bea5'; ctx.font = `${Math.max(10, 11.5 * s)}px serif`;
  ctx.fillText(options.failed ? '请退出后重试' : '愿归途的灯火，始终为你而亮。', width / 2, y + 30 * s);
  ctx.restore();
  return layout;
}
