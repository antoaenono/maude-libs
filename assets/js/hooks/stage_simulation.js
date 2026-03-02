import {
  forceSimulation,
  forceX,
  forceY,
} from "d3-force";

/**
 * Compute deterministic target positions for each node based on role and count.
 * Claude at center, "you" below, "others" in an arc above.
 */
export function computeTargets(nodes, canvasW, canvasH) {
  const centerX = canvasW / 2;
  const centerY = canvasH / 2;
  const targets = {};

  const otherNodes = nodes.filter((n) => n.role === "other");
  const count = otherNodes.length;

  for (const node of nodes) {
    if (node.role === "claude") {
      targets[node.id] = { x: centerX, y: centerY };
    } else if (node.role === "you") {
      targets[node.id] = { x: centerX, y: centerY + 250 };
    } else {
      const idx = otherNodes.indexOf(node);
      const angle = count === 1
        ? Math.PI / 2
        : Math.PI * (0.2 + 0.6 * idx / (count - 1));
      const r = 200;
      targets[node.id] = {
        x: centerX + Math.cos(angle) * r,
        y: centerY - Math.sin(angle) * r,
      };
    }
  }

  return targets;
}

/**
 * Creates a d3 force simulation for stage card layout.
 * Uses only forceX/forceY to pull nodes to deterministic target positions.
 * No forceCollide - positions are pre-computed to avoid overlap.
 *
 * @param {Array<{id: string, role: "claude"|"you"|"other", radius: number, x?: number, y?: number}>} nodes
 * @param {number} canvasW - virtual canvas width (e.g. 1000)
 * @param {number} canvasH - virtual canvas height (e.g. 700)
 * @returns {d3.Simulation}
 */
export function createStageSimulation(nodes, canvasW, canvasH) {
  const centerX = canvasW / 2;
  const centerY = canvasH / 2;
  const targets = computeTargets(nodes, canvasW, canvasH);

  // Set initial positions and fix claude
  for (const node of nodes) {
    const t = targets[node.id];
    if (node.role === "claude") {
      node.fx = centerX;
      node.fy = centerY;
      node.x = centerX;
      node.y = centerY;
    } else if (node.x === undefined || node.y === undefined) {
      node.x = t.x;
      node.y = t.y;
    }
  }

  const sim = forceSimulation(nodes)
    .force(
      "x",
      forceX((d) => targets[d.id].x).strength(1)
    )
    .force(
      "y",
      forceY((d) => targets[d.id].y).strength(1)
    )
    .alphaDecay(0.1)
    .velocityDecay(0.6);

  return sim;
}

/**
 * Clamp non-fixed nodes within canvas bounds, respecting each node's half-dimensions.
 * Uses halfW/halfH for accurate rectangular clamping (not circular radius).
 * Call this per simulation tick.
 */
export function clampToBounds(nodes, canvasW, canvasH) {
  for (const node of nodes) {
    if (node.fx !== undefined && node.fy !== undefined) continue;
    const hw = node.halfW || 0;
    const hh = node.halfH || 0;
    node.x = Math.max(hw, Math.min(canvasW - hw, node.x));
    node.y = Math.max(hh, Math.min(canvasH - hh, node.y));
  }
}

/**
 * Pin the winner node to center and reheat the simulation.
 * Loser nodes are not pinned (caller handles visual treatment).
 */
export function pinWinner(sim, winnerId, centerX, centerY) {
  for (const node of sim.nodes()) {
    if (node.id === winnerId) {
      node.fx = centerX;
      node.fy = centerY;
    } else if (node.role !== "claude") {
      node.fx = undefined;
      node.fy = undefined;
    }
  }
  sim.alpha(0.3).restart();
}
