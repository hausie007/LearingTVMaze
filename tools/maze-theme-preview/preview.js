const THEME_ROOT = "../../themes";

const DIFFICULTY_PRESETS = [
  { id: "very_easy", name: "Very Easy", width: 5, height: 4, seed: 504 },
  { id: "easy", name: "Easy", width: 7, height: 6, seed: 706 },
  { id: "medium", name: "Medium", width: 9, height: 8, seed: 908 },
  { id: "hard", name: "Hard", width: 13, height: 10, seed: 1310 },
  { id: "very_hard", name: "Very Hard", width: 20, height: 12, seed: 2012 },
  { id: "insane", name: "Insane", width: 26, height: 13, seed: 2613 },
  { id: "unbelievable", name: "Unbelievable", width: 36, height: 15, seed: 3615 }
];

const MASK_CASES = [
  { name: "dead north", mask: 1, x: 2, y: 2 },
  { name: "dead east", mask: 2, x: 4, y: 2 },
  { name: "dead south", mask: 4, x: 6, y: 2 },
  { name: "dead west", mask: 8, x: 8, y: 2 },
  { name: "L north-east", mask: 3, x: 2, y: 4 },
  { name: "L east-south", mask: 6, x: 4, y: 4 },
  { name: "L south-west", mask: 12, x: 6, y: 4 },
  { name: "L west-north", mask: 9, x: 8, y: 4 },
  { name: "T no west", mask: 7, x: 2, y: 6 },
  { name: "T no south", mask: 11, x: 4, y: 6 },
  { name: "T no east", mask: 13, x: 6, y: 6 },
  { name: "T no north", mask: 14, x: 8, y: 6 },
  { name: "cross", mask: 15, x: 11, y: 6 }
];

const els = {
  form: document.querySelector("#controls"),
  themeName: document.querySelector("#themeName"),
  boardPreset: document.querySelector("#boardPreset"),
  cellSize: document.querySelector("#cellSize"),
  showLabels: document.querySelector("#showLabels"),
  showSwatches: document.querySelector("#showSwatches"),
  exportPng: document.querySelector("#exportPng"),
  canvas: document.querySelector("#previewCanvas"),
  summary: document.querySelector("#summary"),
  fixtureDescription: document.querySelector("#fixtureDescription"),
  maskList: document.querySelector("#maskList"),
  swatches: document.querySelector("#swatches")
};

const params = new URLSearchParams(location.search);
const initialBoard = params.get("board") || "very_easy";
els.themeName.value = params.get("theme") || "cars";
els.boardPreset.value = initialBoard;
els.cellSize.value = params.has("board") && params.has("cell") ? params.get("cell") : String(suggestedCellForBoard(initialBoard));
els.showLabels.checked = params.get("labels") === "1";
els.showSwatches.checked = params.get("swatches") !== "0";

els.form.addEventListener("submit", event => {
  event.preventDefault();
  render();
});

els.exportPng.addEventListener("click", () => {
  const link = document.createElement("a");
  link.download = `maze-theme-${cleanThemeName(els.themeName.value)}.png`;
  link.href = els.canvas.toDataURL("image/png");
  link.click();
});

els.showLabels.addEventListener("change", render);
els.showSwatches.addEventListener("change", render);
els.cellSize.addEventListener("change", render);
els.boardPreset.addEventListener("change", () => {
  els.cellSize.value = String(suggestedCellForBoard(els.boardPreset.value));
  render();
});

render();

async function render() {
  const themeName = cleanThemeName(els.themeName.value || "cars");
  const boardId = els.boardPreset.value || "very_easy";
  const cellSize = clamp(Number(els.cellSize.value) || suggestedCellForBoard(boardId), 36, 160);
  els.cellSize.value = String(cellSize);
  els.summary.textContent = "Loading...";
  els.swatches.textContent = "";

  const nextUrl = new URL(location.href);
  nextUrl.searchParams.set("theme", themeName);
  nextUrl.searchParams.set("board", boardId);
  nextUrl.searchParams.set("cell", String(cellSize));
  nextUrl.searchParams.set("labels", els.showLabels.checked ? "1" : "0");
  nextUrl.searchParams.set("swatches", els.showSwatches.checked ? "1" : "0");
  history.replaceState(null, "", nextUrl);

  try {
    const loaded = await loadTheme(themeName);
    const graph = buildPreviewGraph(boardId);
    drawPreview(loaded, graph, cellSize);
    updateSummary(loaded, graph, cellSize);
    updateMaskList(graph);
    updateSwatches(loaded);
  } catch (error) {
    els.summary.innerHTML = `<div class="error">${escapeHtml(error.message)}</div>`;
  }
}

async function loadTheme(themeName) {
  const base = `${THEME_ROOT}/${themeName}/`;
  const manifestUrl = `${base}manifest.json`;
  const manifest = await fetchJson(manifestUrl);
  const mazeCfg = manifest.maze_rendering || {};
  const mazeAssets = mazeCfg.assets || {};
  const missing = [];

  const load = (path, label, required = false) => loadImage(base, path, label, required, missing);
  const loadList = async (value, fallback, label) => {
    const paths = normalizeList(value, fallback);
    const images = await Promise.all(paths.map((path, index) => load(path, `${label} ${index}`, true)));
    return images.filter(Boolean);
  };

  const wallJoints = {};
  const jointEntries = Object.entries(mazeAssets.wall_joints || {});
  await Promise.all(jointEntries.map(async ([mask, value]) => {
    const images = await loadList(value, null, `joint ${mask}`);
    if (images.length === 1) {
      wallJoints[Number(mask)] = images[0];
    } else if (images.length > 1) {
      wallJoints[Number(mask)] = images;
    }
  }));

  const assets = {
    floorTextures: await loadList(mazeAssets.floor_tiles, mazeAssets.floor_tile, "floor"),
    wallTopHTextures: await loadList(mazeAssets.wall_top_h_variants, mazeAssets.wall_top_h, "top h"),
    wallTopVTextures: await loadList(mazeAssets.wall_top_v_variants, mazeAssets.wall_top_v, "top v"),
    wallFaceHTextures: await loadList(mazeAssets.wall_face_h_variants, mazeAssets.wall_face_h, "face h"),
    wallHCombinedTextures: await loadList(mazeAssets.wall_h_combined_variants, null, "combined h"),
    wallFaceEndLeftTextures: await loadList(mazeAssets.wall_face_end_left_variants, null, "face end left"),
    wallFaceEndRightTextures: await loadList(mazeAssets.wall_face_end_right_variants, null, "face end right"),
    wallFaceCornerLeftTextures: await loadList(mazeAssets.wall_face_corner_left_variants, null, "face corner left"),
    wallFaceCornerRightTextures: await loadList(mazeAssets.wall_face_corner_right_variants, null, "face corner right"),
    wallTopEndLeftTextures: await loadList(mazeAssets.wall_top_end_left_variants, null, "top end left"),
    wallTopEndRightTextures: await loadList(mazeAssets.wall_top_end_right_variants, null, "top end right"),
    wallTopEndNorthTextures: await loadList(mazeAssets.wall_top_end_north_variants, null, "top end north"),
    wallTopEndSouthTextures: await loadList(mazeAssets.wall_top_end_south_variants, null, "top end south"),
    wallShadowHTexture: await load(mazeAssets.wall_shadow_h, "shadow h", Boolean(mazeAssets.wall_shadow_h)),
    wallShadowHEndLeftTexture: await load(mazeAssets.wall_shadow_h_end_left, "shadow h end left", Boolean(mazeAssets.wall_shadow_h_end_left)),
    wallShadowHEndRightTexture: await load(mazeAssets.wall_shadow_h_end_right, "shadow h end right", Boolean(mazeAssets.wall_shadow_h_end_right)),
    wallShadowVTexture: await load(mazeAssets.wall_shadow_v, "shadow v", Boolean(mazeAssets.wall_shadow_v)),
    wallJointTextures: wallJoints,
    playerTexture: await load(spritePath(manifest, "player", "player.png"), "player"),
    chaserTexture: await load(spritePath(manifest, "chaser", "chaser.png"), "chaser"),
    startTexture: await load(spritePath(manifest, "start", "start.png"), "start"),
    endTexture: await load(spritePath(manifest, "end", "end.png"), "end"),
    collectibleTexture: await load(spritePath(manifest, "collectible", null), "collectible")
  };

  return { themeName, base, manifest, mazeCfg, mazeAssets, assets, missing };
}

function drawPreview(loaded, graph, cellSize) {
  const { manifest, mazeCfg, assets } = loaded;
  const metrics = buildMetrics(cellSize, mazeCfg);
  const board = {
    width: graph.width * cellSize,
    height: graph.height * cellSize
  };
  const margin = 28;
  const bleed = {
    left: metrics.topW * 0.62,
    top: metrics.topW * 0.62,
    right: metrics.topW * 0.62,
    bottom: metrics.topW * 0.62 + metrics.faceD + metrics.shadowD
  };
  const swatchBand = els.showSwatches.checked ? 0 : 0;
  const cssWidth = Math.ceil(margin * 2 + bleed.left + board.width + bleed.right);
  const cssHeight = Math.ceil(margin * 2 + bleed.top + board.height + bleed.bottom + swatchBand);
  const dpr = Math.max(1, window.devicePixelRatio || 1);
  const canvas = els.canvas;
  canvas.style.width = `${cssWidth}px`;
  canvas.style.height = `${cssHeight}px`;
  canvas.width = Math.ceil(cssWidth * dpr);
  canvas.height = Math.ceil(cssHeight * dpr);

  const ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = "high";

  ctx.fillStyle = manifest.colors?.wall_border || "#252c35";
  ctx.fillRect(0, 0, cssWidth, cssHeight);

  const offset = {
    x: margin + bleed.left,
    y: margin + bleed.top
  };

  drawAssetMaze(ctx, graph, assets, metrics, offset, board, manifest);
  drawFixtureSprites(ctx, assets, metrics, offset, graph, manifest);
  if (els.showLabels.checked && graph.kind === "fixture") {
    drawShapeLabels(ctx, metrics, offset);
  }
}

function drawAssetMaze(ctx, graph, assets, metrics, offset, board, manifest) {
  drawFloor(ctx, assets, offset, board, manifest);
  drawRoadMarkings(ctx, graph, metrics, offset, manifest.maze_rendering || {});

  const hRuns = graph.horizontalRuns();
  const vRuns = graph.verticalRuns();
  const allRuns = [...hRuns, ...vRuns];
  const useCombinedH = assets.wallHCombinedTextures.length > 0;

  for (const run of allRuns) {
    if (run.orientation === "h") drawHorizontalShadow(ctx, run, assets, metrics, offset);
    if (run.orientation === "v") drawVerticalShadow(ctx, run, assets, metrics, offset);
  }

  if (useCombinedH) {
    for (const run of hRuns) {
      drawCombinedHorizontalRun(ctx, graph, run, assets, metrics, offset);
    }
  } else {
    for (const run of hRuns) {
      drawFrontFaceRun(ctx, graph, run, assets, metrics, offset);
    }
    for (const run of hRuns) {
      const rect = rectForHorizontalRun(run, metrics, offset);
      const tex = pickVariant(assets.wallTopHTextures, run.x0, run.y);
      if (tex) drawTiledScaled(ctx, tex, rect, true);
    }
  }

  for (const run of vRuns) {
    const rect = rectForVerticalRun(run, metrics, offset);
    const tex = pickVariant(assets.wallTopVTextures, run.x, run.y0);
    if (tex) drawTiledScaled(ctx, tex, rect, false);
  }

  for (const info of graph.vertexMasks()) {
    const { mask, x, y } = info;
    if (mask === 5 || mask === 10) continue;
    const degree = maskDegree(mask);
    let tex = null;
    if (degree <= 1) {
      if (mask === 1) tex = pickVariant(assets.wallTopEndSouthTextures, x, y);
      if (mask === 2) tex = pickVariant(assets.wallTopEndLeftTextures, x, y);
      if (mask === 4) tex = pickVariant(assets.wallTopEndNorthTextures, x, y);
      if (mask === 8) tex = pickVariant(assets.wallTopEndRightTextures, x, y);
    } else {
      tex = pickJointTexture(assets.wallJointTextures[mask], x, y);
    }
    if (!tex) continue;
    const assetSize = metrics.topW * (degree > 1 ? 1.04 : 1.08);
    const size = Math.max(assetSize, metrics.junctionW);
    drawTextureScaled(ctx, tex, {
      x: offset.x + x * metrics.cs - size * 0.5,
      y: offset.y + y * metrics.cs - size * 0.5,
      w: size,
      h: size
    });
  }
}

function drawRoadMarkings(ctx, graph, metrics, offset, mazeCfg) {
  const cfg = mazeCfg.road_markings || {};
  if (!cfg.enabled) return;

  const color = cfg.color || "rgba(255, 255, 255, 0.42)";
  const shadowColor = cfg.shadow_color || "rgba(0, 0, 0, 0.20)";
  const dashLen = clamp(metrics.cs * Number(cfg.dash_length_ratio ?? 0.38), metrics.cs * 0.22, metrics.cs * 0.55);
  const lineW = clamp(metrics.cs * Number(cfg.width_ratio ?? 0.026), 1.6, 4.5);

  ctx.save();
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  for (let y = 0; y < graph.height; y += 1) {
    for (let x = 0; x < graph.width; x += 1) {
      const openHorizontal = !graph.hasV(x, y) || !graph.hasV(x + 1, y);
      const openVertical = !graph.hasH(x, y) || !graph.hasH(x, y + 1);
      const cx = offset.x + (x + 0.5) * metrics.cs;
      const cy = offset.y + (y + 0.5) * metrics.cs;
      if (openHorizontal && !openVertical) {
        drawRoadDash(ctx, cx - dashLen * 0.5, cy, cx + dashLen * 0.5, cy, lineW, color, shadowColor);
      } else if (openVertical && !openHorizontal) {
        drawRoadDash(ctx, cx, cy - dashLen * 0.5, cx, cy + dashLen * 0.5, lineW, color, shadowColor);
      }
    }
  }
  ctx.restore();
}

function drawRoadDash(ctx, x0, y0, x1, y1, lineW, color, shadowColor) {
  ctx.strokeStyle = shadowColor;
  ctx.lineWidth = lineW * 1.55;
  ctx.beginPath();
  ctx.moveTo(x0, y0 + lineW * 0.35);
  ctx.lineTo(x1, y1 + lineW * 0.35);
  ctx.stroke();

  ctx.strokeStyle = color;
  ctx.lineWidth = lineW;
  ctx.beginPath();
  ctx.moveTo(x0, y0);
  ctx.lineTo(x1, y1);
  ctx.stroke();
}

function drawFloor(ctx, assets, offset, board, manifest) {
  const textures = assets.floorTextures;
  if (!textures.length) {
    ctx.fillStyle = manifest.colors?.floor || "#202932";
    ctx.fillRect(offset.x, offset.y, board.width, board.height);
    return;
  }

  ctx.save();
  ctx.beginPath();
  ctx.rect(offset.x, offset.y, board.width, board.height);
  ctx.clip();

  if (textures.length === 1) {
    const pattern = ctx.createPattern(textures[0], "repeat");
    ctx.fillStyle = pattern || "#202932";
    ctx.fillRect(offset.x, offset.y, board.width, board.height);
  } else {
    const tileW = textures[0].naturalWidth || textures[0].width;
    const tileH = textures[0].naturalHeight || textures[0].height;
    let row = 0;
    for (let y = offset.y; y < offset.y + board.height - 0.5; y += tileH) {
      let col = 0;
      for (let x = offset.x; x < offset.x + board.width - 0.5; x += tileW) {
        const tex = pickVariant(textures, col, row);
        ctx.drawImage(tex, x, y, tileW, tileH);
        col += 1;
      }
      row += 1;
    }
  }
  ctx.restore();
}

function drawHorizontalShadow(ctx, run, assets, metrics, offset) {
  const x0 = offset.x + run.x0 * metrics.cs;
  const x1 = offset.x + run.x1 * metrics.cs;
  const y = offset.y + run.y * metrics.cs;
  const rect = {
    x: x0 - metrics.topW * 0.15,
    y: y + metrics.topW * 0.45 + metrics.faceD * 0.38,
    w: (x1 - x0) + metrics.topW * 0.30,
    h: metrics.faceD * 0.62 + metrics.shadowD
  };

  if (assets.wallShadowHTexture) {
    if (assets.wallShadowHEndLeftTexture && assets.wallShadowHEndRightTexture && rect.w > metrics.topW * 2.4) {
      const capW = Math.min(metrics.topW * 1.25, rect.w * 0.45);
      drawTiledScaled(ctx, assets.wallShadowHTexture, {
        x: rect.x + capW * 0.5,
        y: rect.y,
        w: rect.w - capW,
        h: rect.h
      }, true);
      drawTextureScaled(ctx, assets.wallShadowHEndLeftTexture, { x: rect.x, y: rect.y, w: capW, h: rect.h });
      drawTextureScaled(ctx, assets.wallShadowHEndRightTexture, { x: rect.x + rect.w - capW, y: rect.y, w: capW, h: rect.h });
    } else {
      drawTiledScaled(ctx, assets.wallShadowHTexture, rect, true);
    }
  } else {
    ctx.fillStyle = "rgba(0,0,0,.18)";
    ctx.fillRect(rect.x, rect.y, rect.w, rect.h);
  }
}

function drawVerticalShadow(ctx, run, assets, metrics, offset) {
  const x = offset.x + run.x * metrics.cs;
  const y0 = offset.y + run.y0 * metrics.cs;
  const y1 = offset.y + run.y1 * metrics.cs;
  const rect = {
    x: x + metrics.topW * 0.40,
    y: y0 + metrics.topW * 0.20,
    w: metrics.shadowD,
    h: (y1 - y0) + metrics.topW * 0.15
  };

  if (assets.wallShadowVTexture) {
    drawTiledScaled(ctx, assets.wallShadowVTexture, rect, false);
  } else {
    ctx.fillStyle = "rgba(0,0,0,.12)";
    ctx.fillRect(rect.x, rect.y, rect.w, rect.h);
  }
}

function drawFrontFaceRun(ctx, graph, run, assets, metrics, offset) {
  const runX0 = offset.x + run.x0 * metrics.cs;
  const runX1 = offset.x + run.x1 * metrics.cs;
  const y = offset.y + run.y * metrics.cs;
  const x0 = runX0 + metrics.topW * 0.58;
  const x1 = runX1 - metrics.topW * 0.58;
  if (x1 <= x0 + 2) return;

  const faceRect = {
    x: x0,
    y: y + metrics.topW * 0.45,
    w: x1 - x0,
    h: metrics.faceD
  };
  const faceTex = pickVariant(assets.wallFaceHTextures, run.x0, run.y);
  if (faceTex) {
    drawTiledScaled(ctx, faceTex, faceRect, true);
  } else {
    ctx.fillStyle = "#2c2934";
    ctx.fillRect(faceRect.x, faceRect.y, faceRect.w, faceRect.h);
  }

  const leftList = graph.isExposedHorizontalEnd(run.x0, run.y)
    ? assets.wallFaceEndLeftTextures
    : assets.wallFaceCornerLeftTextures;
  const rightList = graph.isExposedHorizontalEnd(run.x1, run.y)
    ? assets.wallFaceEndRightTextures
    : assets.wallFaceCornerRightTextures;
  drawFacePiece(ctx, pickVariant(leftList, run.x0, run.y), runX0, y, true, metrics);
  drawFacePiece(ctx, pickVariant(rightList, run.x1, run.y), runX1, y, false, metrics);
}

function drawCombinedHorizontalRun(ctx, graph, run, assets, metrics, offset) {
  const runX0 = offset.x + run.x0 * metrics.cs;
  const runX1 = offset.x + run.x1 * metrics.cs;
  const y = offset.y + run.y * metrics.cs;
  const tex = pickVariant(assets.wallHCombinedTextures, run.x0, run.y);
  if (tex) {
    drawTiledScaled(ctx, tex, {
      x: runX0,
      y: y - metrics.topW * 0.50,
      w: runX1 - runX0,
      h: metrics.topW * 0.95 + metrics.faceD
    }, true);
  }

  const leftList = graph.isExposedHorizontalEnd(run.x0, run.y)
    ? assets.wallFaceEndLeftTextures
    : assets.wallFaceCornerLeftTextures;
  const rightList = graph.isExposedHorizontalEnd(run.x1, run.y)
    ? assets.wallFaceEndRightTextures
    : assets.wallFaceCornerRightTextures;
  drawFacePiece(ctx, pickVariant(leftList, run.x0, run.y), runX0, y, true, metrics);
  drawFacePiece(ctx, pickVariant(rightList, run.x1, run.y), runX1, y, false, metrics);
}

function drawFacePiece(ctx, tex, vertexX, y, isLeft, metrics) {
  if (!tex) return;
  const pieceW = metrics.topW * 0.94;
  const x = isLeft ? vertexX + metrics.topW * 0.02 : vertexX - pieceW - metrics.topW * 0.02;
  drawTextureScaled(ctx, tex, {
    x,
    y: y + metrics.topW * 0.45,
    w: pieceW,
    h: metrics.faceD
  });
}

function rectForHorizontalRun(run, metrics, offset) {
  const x0 = offset.x + run.x0 * metrics.cs;
  const x1 = offset.x + run.x1 * metrics.cs;
  const y = offset.y + run.y * metrics.cs;
  return { x: x0, y: y - metrics.topW * 0.50, w: x1 - x0, h: metrics.topW };
}

function rectForVerticalRun(run, metrics, offset) {
  const y0 = offset.y + run.y0 * metrics.cs;
  const y1 = offset.y + run.y1 * metrics.cs;
  const x = offset.x + run.x * metrics.cs;
  return { x: x - metrics.topW * 0.50, y: y0, w: metrics.topW, h: y1 - y0 };
}

function drawFixtureSprites(ctx, assets, metrics, offset, graph, manifest) {
  const props = graph.props || {};
  if (props.start) drawSprite(ctx, assets.startTexture, offset, metrics, props.start.x, props.start.y, 0.80);
  if (props.end) drawSprite(ctx, assets.endTexture, offset, metrics, props.end.x, props.end.y, 0.80);
  if (props.collectibles) {
    const colors = collectibleLabelColors(manifest);
    for (const item of props.collectibles) {
      drawCollectible(ctx, assets.collectibleTexture, offset, metrics, item.x, item.y, item.label, colors);
    }
  }
  if (props.chaser) drawSprite(ctx, assets.chaserTexture, offset, metrics, props.chaser.x, props.chaser.y, 0.75);
  if (props.player) drawSprite(ctx, assets.playerTexture, offset, metrics, props.player.x, props.player.y, 0.80);
}

function drawSprite(ctx, image, offset, metrics, cellX, cellY, sizeInCells) {
  if (!image) return;
  const cx = offset.x + (cellX + 0.5) * metrics.cs;
  const cy = offset.y + (cellY + 0.5) * metrics.cs;
  const maxW = metrics.cs * sizeInCells;
  const maxH = metrics.cs * sizeInCells;
  const ratio = Math.min(maxW / image.naturalWidth, maxH / image.naturalHeight);
  const w = image.naturalWidth * ratio;
  const h = image.naturalHeight * ratio;
  ctx.drawImage(image, cx - w * 0.5, cy - h * 0.5, w, h);
}

function drawCollectible(ctx, image, offset, metrics, cellX, cellY, label, colors) {
  const cx = offset.x + (cellX + 0.5) * metrics.cs;
  const cy = offset.y + (cellY + 0.5) * metrics.cs;
  if (image) {
    drawSprite(ctx, image, offset, metrics, cellX, cellY, 0.70);
    drawCollectibleLabel(ctx, cx, cy, metrics, label, colors.fill, colors.stroke);
    return;
  }

  const r = metrics.cs * 0.32;
  const gradient = ctx.createRadialGradient(cx - r * 0.35, cy - r * 0.45, r * 0.15, cx, cy, r);
  gradient.addColorStop(0, "#fff3a6");
  gradient.addColorStop(0.65, "#ffcb32");
  gradient.addColorStop(1, "#8d5a00");
  ctx.fillStyle = gradient;
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.fill();
  ctx.lineWidth = 3;
  ctx.strokeStyle = "#fff7c5";
  ctx.stroke();
  drawCollectibleLabel(ctx, cx, cy, metrics, label, colors.fill, colors.stroke);
}

function collectibleLabelColors(manifest) {
  const cfg = manifest.collectible || {};
  const fill = cfg["text-color"] || cfg.text_color || "#ffffff";
  const stroke = cfg["text-outline-color"] || cfg.text_outline_color || (isLightHex(fill) ? "#111827" : "#ffffff");
  return { fill, stroke };
}

function isLightHex(color) {
  const match = /^#?([0-9a-f]{6})$/i.exec(String(color || ""));
  if (!match) return false;
  const value = match[1];
  const r = parseInt(value.slice(0, 2), 16) / 255;
  const g = parseInt(value.slice(2, 4), 16) / 255;
  const b = parseInt(value.slice(4, 6), 16) / 255;
  return 0.299 * r + 0.587 * g + 0.114 * b > 0.58;
}

function drawCollectibleLabel(ctx, cx, cy, metrics, label, fill, stroke) {
  ctx.fillStyle = fill;
  ctx.strokeStyle = stroke;
  ctx.lineWidth = Math.max(2, metrics.cs * 0.045);
  ctx.font = `800 ${Math.round(metrics.cs * 0.34)}px system-ui, sans-serif`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.strokeText(label, cx, cy + 1);
  ctx.fillText(label, cx, cy + 1);
}

function drawShapeLabels(ctx, metrics, offset) {
  ctx.save();
  ctx.font = "600 11px system-ui, sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  for (const item of MASK_CASES) {
    const x = offset.x + item.x * metrics.cs;
    const y = offset.y + item.y * metrics.cs - metrics.topW * 1.45;
    const text = `${item.mask} ${item.name}`;
    const width = ctx.measureText(text).width + 12;
    ctx.fillStyle = "rgba(9,14,20,.78)";
    roundRect(ctx, x - width * 0.5, y - 11, width, 22, 6);
    ctx.fill();
    ctx.fillStyle = "#dbeafe";
    ctx.fillText(text, x, y + 0.5);
  }
  ctx.restore();
}

function drawTiledScaled(ctx, image, rect, horizontal) {
  if (!image || rect.w <= 0 || rect.h <= 0) return;
  ctx.save();
  ctx.beginPath();
  ctx.rect(rect.x, rect.y, rect.w, rect.h);
  ctx.clip();

  if (horizontal) {
    const scale = rect.h / image.naturalHeight;
    const tileW = image.naturalWidth * scale;
    const endX = rect.x + rect.w;
    for (let x = rect.x; x < endX - 0.01; x += tileW) {
      const drawW = Math.min(tileW, endX - x);
      const srcW = drawW / scale;
      ctx.drawImage(image, 0, 0, srcW, image.naturalHeight, x, rect.y, drawW, rect.h);
    }
  } else {
    const scale = rect.w / image.naturalWidth;
    const tileH = image.naturalHeight * scale;
    const endY = rect.y + rect.h;
    for (let y = rect.y; y < endY - 0.01; y += tileH) {
      const drawH = Math.min(tileH, endY - y);
      const srcH = drawH / scale;
      ctx.drawImage(image, 0, 0, image.naturalWidth, srcH, rect.x, y, rect.w, drawH);
    }
  }
  ctx.restore();
}

function drawTextureScaled(ctx, image, rect) {
  if (!image || rect.w <= 0 || rect.h <= 0) return;
  ctx.drawImage(image, rect.x, rect.y, rect.w, rect.h);
}

function buildMetrics(cellSize, mazeCfg) {
  return {
    cs: cellSize,
    topW: clamp(cellSize * Number(mazeCfg.top_width_ratio ?? 0.24), 10, 30),
    faceD: clamp(cellSize * Number(mazeCfg.front_depth_ratio ?? 0.17), 8, 24),
    shadowD: clamp(cellSize * Number(mazeCfg.shadow_depth_ratio ?? 0.13), 4, 14),
    junctionW: cellSize * Number(mazeCfg.node_scale_ratio ?? 0.29)
  };
}

function suggestedCellForBoard(boardId) {
  const sizes = {
    very_easy: 128,
    easy: 112,
    medium: 96,
    hard: 72,
    very_hard: 56,
    insane: 48,
    unbelievable: 40,
    all_masks: 96
  };
  return sizes[boardId] || 56;
}

function buildFixtureGraph() {
  const graph = new WallGraph(16, 11);
  graph.kind = "fixture";
  graph.label = "All Masks Zoom";
  graph.props = {
    player: { x: 1.4, y: 9.3 },
    chaser: { x: 11.7, y: 2.0 },
    end: { x: 11.7, y: 9.2 },
    collectibles: [
      { x: 11.4, y: 3.6, label: "A" },
      { x: 12.0, y: 7.9, label: "B" },
      { x: 5.9, y: 8.8, label: "C" }
    ]
  };
  graph.addRect(0, 0, 16, 11);

  for (const item of MASK_CASES) {
    graph.addMask(item.x, item.y, item.mask);
  }

  // Compact run samples: exposed horizontal ends, connected face corners,
  // vertical tops, and one longer strip without turning this into a fake maze.
  graph.addHRun(1, 5, 8);
  graph.addHRun(7, 10, 8);
  graph.addVRun(7, 8, 9);
  graph.addHRun(11, 14, 8);
  graph.addVRun(14, 8, 9);
  graph.addHRun(3, 10, 10);

  return graph;
}

function buildPreviewGraph(boardId) {
  if (boardId === "all_masks") return buildFixtureGraph();
  const preset = DIFFICULTY_PRESETS.find(item => item.id === boardId) || DIFFICULTY_PRESETS[0];
  return buildDifficultyGraph(preset);
}

function buildDifficultyGraph(preset) {
  const maze = generateCompactMaze(preset.width, preset.height, preset.seed);
  const graph = new WallGraph(preset.width, preset.height);
  graph.kind = "difficulty";
  graph.label = `${preset.name} ${preset.width}x${preset.height}`;
  graph.props = buildDifficultyProps(preset.width, preset.height);

  for (let y = 0; y < preset.height; y += 1) {
    for (let x = 0; x < preset.width; x += 1) {
      const cell = maze[y][x];
      if (cell.n) graph.addH(x, y);
      if (cell.s) graph.addH(x, y + 1);
      if (cell.w) graph.addV(x, y);
      if (cell.e) graph.addV(x + 1, y);
    }
  }

  return graph;
}

function buildDifficultyProps(width, height) {
  const used = new Set([`0,${height - 1}`, `${width - 1},0`, `${width - 1},${height - 1}`]);
  const collectibles = [];
  for (const item of [
    { x: Math.floor(width * 0.42), y: Math.floor(height * 0.34), label: "1" },
    { x: Math.floor(width * 0.68), y: Math.floor(height * 0.58), label: "2" },
    { x: Math.floor(width * 0.28), y: height - 2, label: "3" }
  ]) {
    const cell = {
      x: clamp(item.x, 0, width - 1),
      y: clamp(item.y, 0, height - 1),
      label: item.label
    };
    const key = `${cell.x},${cell.y}`;
    if (!used.has(key)) {
      collectibles.push(cell);
      used.add(key);
    }
  }

  return {
    start: { x: 0, y: height - 1 },
    end: { x: width - 1, y: 0 },
    player: { x: 0, y: height - 1 },
    chaser: { x: width - 1, y: height - 1 },
    collectibles
  };
}

function generateCompactMaze(width, height, seed) {
  const maze = Array.from({ length: height }, () => Array.from({ length: width }, () => ({
    n: true,
    e: true,
    s: true,
    w: true,
    visited: false
  })));
  const rng = createRng(seed);
  const stack = [{ x: 0, y: height - 1 }];
  maze[height - 1][0].visited = true;

  while (stack.length) {
    const current = stack[stack.length - 1];
    const neighbors = [];
    for (const dir of [
      { dx: 0, dy: -1, a: "n", b: "s" },
      { dx: 1, dy: 0, a: "e", b: "w" },
      { dx: 0, dy: 1, a: "s", b: "n" },
      { dx: -1, dy: 0, a: "w", b: "e" }
    ]) {
      const nx = current.x + dir.dx;
      const ny = current.y + dir.dy;
      if (nx >= 0 && nx < width && ny >= 0 && ny < height && !maze[ny][nx].visited) {
        neighbors.push({ x: nx, y: ny, dir });
      }
    }

    if (!neighbors.length) {
      stack.pop();
      continue;
    }

    const next = neighbors[Math.floor(rng() * neighbors.length)];
    maze[current.y][current.x][next.dir.a] = false;
    maze[next.y][next.x][next.dir.b] = false;
    maze[next.y][next.x].visited = true;
    stack.push({ x: next.x, y: next.y });
  }

  return maze;
}

function createRng(seed) {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

class WallGraph {
  constructor(width, height) {
    this.width = width;
    this.height = height;
    this.kind = "custom";
    this.label = `${width}x${height}`;
    this.props = {};
    this.h = new Set();
    this.v = new Set();
  }

  addRect(x0, y0, x1, y1) {
    this.addHRun(x0, x1, y0);
    this.addHRun(x0, x1, y1);
    this.addVRun(x0, y0, y1);
    this.addVRun(x1, y0, y1);
  }

  addMask(x, y, mask) {
    if (mask & 1) this.addV(x, y - 1);
    if (mask & 2) this.addH(x, y);
    if (mask & 4) this.addV(x, y);
    if (mask & 8) this.addH(x - 1, y);
  }

  addHRun(x0, x1, y) {
    for (let x = x0; x < x1; x += 1) this.addH(x, y);
  }

  addVRun(x, y0, y1) {
    for (let y = y0; y < y1; y += 1) this.addV(x, y);
  }

  addH(x, y) {
    if (x >= 0 && x < this.width && y >= 0 && y <= this.height) {
      this.h.add(`${x},${y}`);
    }
  }

  addV(x, y) {
    if (x >= 0 && x <= this.width && y >= 0 && y < this.height) {
      this.v.add(`${x},${y}`);
    }
  }

  hasH(x, y) {
    return this.h.has(`${x},${y}`);
  }

  hasV(x, y) {
    return this.v.has(`${x},${y}`);
  }

  isExposedHorizontalEnd(x, y) {
    return !this.hasV(x, y - 1) && !this.hasV(x, y);
  }

  horizontalRuns() {
    const runs = [];
    for (let y = 0; y <= this.height; y += 1) {
      let x = 0;
      while (x < this.width) {
        if (!this.hasH(x, y)) {
          x += 1;
          continue;
        }
        const x0 = x;
        while (x < this.width && this.hasH(x, y)) x += 1;
        runs.push({ orientation: "h", x0, x1: x, y });
      }
    }
    return runs;
  }

  verticalRuns() {
    const runs = [];
    for (let x = 0; x <= this.width; x += 1) {
      let y = 0;
      while (y < this.height) {
        if (!this.hasV(x, y)) {
          y += 1;
          continue;
        }
        const y0 = y;
        while (y < this.height && this.hasV(x, y)) y += 1;
        runs.push({ orientation: "v", x, y0, y1: y });
      }
    }
    return runs;
  }

  vertexMasks() {
    const vertices = [];
    for (let y = 0; y <= this.height; y += 1) {
      for (let x = 0; x <= this.width; x += 1) {
        let mask = 0;
        if (this.hasV(x, y - 1)) mask |= 1;
        if (this.hasH(x, y)) mask |= 2;
        if (this.hasV(x, y)) mask |= 4;
        if (this.hasH(x - 1, y)) mask |= 8;
        if (mask) vertices.push({ x, y, mask });
      }
    }
    return vertices;
  }
}

function updateSummary(loaded, graph, cellSize) {
  const { manifest, mazeCfg, assets, missing, themeName } = loaded;
  const loadedAssetCount = Object.entries(assets).reduce((total, [, value]) => {
    if (Array.isArray(value)) return total + value.length;
    if (value && typeof value === "object" && !(value instanceof HTMLImageElement)) return total + countNestedAssets(value);
    return total + (value ? 1 : 0);
  }, 0);
  const presentMasks = [...new Set(graph.vertexMasks().map(item => item.mask))].sort((a, b) => a - b);
  const rows = [
    ["theme", `${manifest.title || themeName} (${themeName})`],
    ["board", graph.label],
    ["wall mode", mazeCfg.wall_mode || "simple"],
    ["cell size", `${cellSize}px`],
    ["assets", `${loadedAssetCount} loaded${missing.length ? `, ${missing.length} missing` : ""}`],
    ["masks", presentMasks.join(", ")]
  ];
  els.summary.innerHTML = rows.map(([key, value]) => (
    `<div class="summary-row"><span>${escapeHtml(key)}</span><span>${escapeHtml(value)}</span></div>`
  )).join("");
  if (missing.length) {
    els.summary.insertAdjacentHTML("beforeend", `<div class="error">${escapeHtml(missing.map(item => item.path).join(", "))}</div>`);
  }
}

function updateMaskList(graph) {
  if (graph.kind === "fixture") {
    els.fixtureDescription.textContent = "Zoom inspection board: every dead end, straight, L, T, and cross mask is deliberately separated and enlarged so seams and pixel alignment are easy to inspect.";
  } else {
    els.fixtureDescription.textContent = "Godot difficulty footprint: deterministic compact maze using the real grid dimensions for this level.";
  }
  const presentMasks = [...new Set(graph.vertexMasks().map(item => item.mask))].sort((a, b) => a - b);
  els.maskList.innerHTML = presentMasks.map(mask => (
    `<span class="mask-chip">${mask}: ${escapeHtml(maskName(mask))}</span>`
  )).join("");
}

function updateSwatches(loaded) {
  if (!els.showSwatches.checked) {
    els.swatches.textContent = "Swatches hidden.";
    return;
  }
  const a = loaded.assets;
  const groups = [
    ["floor", a.floorTextures],
    ["wall top horizontal", a.wallTopHTextures],
    ["combined horizontal wall", a.wallHCombinedTextures],
    ["wall top vertical", a.wallTopVTextures],
    ["front face horizontal", a.wallFaceHTextures],
    ["front face ends", [...a.wallFaceEndLeftTextures, ...a.wallFaceEndRightTextures]],
    ["front face connected corners", [...a.wallFaceCornerLeftTextures, ...a.wallFaceCornerRightTextures]],
    ["top dead-end caps", [...a.wallTopEndLeftTextures, ...a.wallTopEndRightTextures, ...a.wallTopEndNorthTextures, ...a.wallTopEndSouthTextures]],
    ["shadows", [a.wallShadowHTexture, a.wallShadowHEndLeftTexture, a.wallShadowHEndRightTexture, a.wallShadowVTexture].filter(Boolean)],
    ["junction masks", Object.entries(a.wallJointTextures).sort(([left], [right]) => Number(left) - Number(right)).flatMap(([, image]) => Array.isArray(image) ? image : [image])],
    ["sprites", [a.playerTexture, a.chaserTexture, a.startTexture, a.endTexture, a.collectibleTexture].filter(Boolean)]
  ].filter(([, images]) => images.length);

  els.swatches.innerHTML = groups.map(([title, images]) => {
    const cells = images.map(image => `<div class="swatch" title="${escapeHtml(image.dataset.path || "")}"><img src="${escapeHtml(image.src)}" alt=""></div>`).join("");
    return `<div class="swatch-group"><div class="swatch-title">${escapeHtml(title)}</div><div class="swatch-strip">${cells}</div></div>`;
  }).join("");
}

function spritePath(manifest, key, fallback) {
  if (manifest.assets && typeof manifest.assets[key] === "string") return manifest.assets[key];
  const cfg = manifest[key];
  if (cfg && typeof cfg.image === "string") return cfg.image;
  if (cfg && Array.isArray(cfg.frames) && cfg.frames.length) return cfg.frames[0];
  return fallback;
}

async function fetchJson(url) {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`Cannot load ${url} (${response.status})`);
  return response.json();
}

function loadImage(base, path, label, required, missing) {
  if (!path || typeof path !== "string") return Promise.resolve(null);
  const url = `${base}${path}`;
  return new Promise(resolve => {
    const image = new Image();
    image.onload = () => {
      image.dataset.path = path;
      resolve(image);
    };
    image.onerror = () => {
      if (required) missing.push({ path, label, required });
      resolve(null);
    };
    image.src = `${url}?v=${Date.now()}`;
  });
}

function normalizeList(value, fallback) {
  if (Array.isArray(value) && value.length) return value;
  if (typeof value === "string" && value) return [value];
  if (typeof fallback === "string" && fallback) return [fallback];
  return [];
}

function pickVariant(list, x, y) {
  if (!list || !list.length) return null;
  return list[variantIndex(x, y, list.length)];
}

function pickJointTexture(value, x, y) {
  if (Array.isArray(value)) return pickVariant(value, x, y);
  return value || null;
}

function countNestedAssets(value) {
  return Object.values(value).reduce((total, item) => total + (Array.isArray(item) ? item.length : item ? 1 : 0), 0);
}

function variantIndex(x, y, count) {
  if (count <= 1) return 0;
  let value = Math.imul(x | 0, 92837111) ^ Math.imul(y | 0, 689287499) ^ 0x45d9f3b;
  value ^= value >>> 16;
  return Math.abs(value) % count;
}

function maskDegree(mask) {
  let degree = 0;
  for (const bit of [1, 2, 4, 8]) if (mask & bit) degree += 1;
  return degree;
}

function maskName(mask) {
  const names = {
    1: "dead north",
    2: "dead east",
    3: "L north-east",
    4: "dead south",
    5: "vertical straight",
    6: "L east-south",
    7: "T no west",
    8: "dead west",
    9: "L west-north",
    10: "horizontal straight",
    11: "T no south",
    12: "L south-west",
    13: "T no east",
    14: "T no north",
    15: "cross"
  };
  return names[mask] || "unknown";
}

function roundRect(ctx, x, y, w, h, radius) {
  const r = Math.min(radius, w * 0.5, h * 0.5);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
}

function cleanThemeName(value) {
  return String(value || "").trim().replace(/^\/+|\/+$/g, "") || "cars";
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
