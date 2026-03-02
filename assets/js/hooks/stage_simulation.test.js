import { describe, it, expect } from "vitest";
import {
  createStageSimulation,
  computeTargets,
  clampToBounds,
  pinWinner,
} from "./stage_simulation";

const CANVAS_W = 1000;
const CANVAS_H = 700;
const CENTER_X = CANVAS_W / 2;
const CENTER_Y = CANVAS_H / 2;

function runToCompletion(sim) {
  while (sim.alpha() > sim.alphaMin()) {
    sim.tick();
  }
}

function makeNode(id, role, halfW = 40, halfH = 40) {
  return { id, role, halfW, halfH };
}

function distance(a, b) {
  return Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2);
}

function findNode(sim, id) {
  return sim.nodes().find((n) => n.id === id);
}

describe("computeTargets", () => {
  it("places claude at center", () => {
    const nodes = [makeNode("claude", "claude"), makeNode("you", "you")];
    const targets = computeTargets(nodes, CANVAS_W, CANVAS_H);
    expect(targets.claude).toEqual({ x: CENTER_X, y: CENTER_Y });
  });

  it("places you below center", () => {
    const nodes = [makeNode("claude", "claude"), makeNode("you", "you")];
    const targets = computeTargets(nodes, CANVAS_W, CANVAS_H);
    expect(targets.you.x).toBe(CENTER_X);
    expect(targets.you.y).toBeGreaterThan(CENTER_Y);
  });

  it("places single other directly above center", () => {
    const nodes = [
      makeNode("claude", "claude"),
      makeNode("you", "you"),
      makeNode("alice", "other"),
    ];
    const targets = computeTargets(nodes, CANVAS_W, CANVAS_H);
    expect(targets.alice.x).toBeCloseTo(CENTER_X, 0);
    expect(targets.alice.y).toBeLessThan(CENTER_Y);
  });

  it("spreads multiple others in an arc above center", () => {
    const nodes = [
      makeNode("claude", "claude"),
      makeNode("you", "you"),
      makeNode("alice", "other"),
      makeNode("bob", "other"),
    ];
    const targets = computeTargets(nodes, CANVAS_W, CANVAS_H);
    // Both above center
    expect(targets.alice.y).toBeLessThan(CENTER_Y);
    expect(targets.bob.y).toBeLessThan(CENTER_Y);
    // Spread horizontally
    expect(targets.alice.x).not.toBeCloseTo(targets.bob.x, 0);
  });

  it("is deterministic for same inputs", () => {
    const makeNodes = () => [
      makeNode("claude", "claude"),
      makeNode("you", "you"),
      makeNode("alice", "other"),
      makeNode("bob", "other"),
    ];
    const t1 = computeTargets(makeNodes(), CANVAS_W, CANVAS_H);
    const t2 = computeTargets(makeNodes(), CANVAS_W, CANVAS_H);
    expect(t1).toEqual(t2);
  });
});

describe("createStageSimulation", () => {
  describe("core positioning", () => {
    it("claude node stays fixed at center", () => {
      const nodes = [
        makeNode("claude", "claude"),
        makeNode("you", "you"),
        makeNode("alice", "other"),
      ];
      const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
      runToCompletion(sim);

      const claude = findNode(sim, "claude");
      expect(claude.x).toBe(CENTER_X);
      expect(claude.y).toBe(CENTER_Y);
    });

    it("your card settles below claude, near horizontal center", () => {
      const nodes = [
        makeNode("claude", "claude"),
        makeNode("you", "you"),
        makeNode("alice", "other"),
      ];
      const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
      runToCompletion(sim);

      const you = findNode(sim, "you");
      expect(you.y).toBeGreaterThan(CENTER_Y);
      expect(Math.abs(you.x - CENTER_X)).toBeLessThan(10);
    });

    it("other nodes settle above claude", () => {
      const nodes = [
        makeNode("claude", "claude"),
        makeNode("you", "you"),
        makeNode("alice", "other"),
        makeNode("bob", "other"),
      ];
      const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
      runToCompletion(sim);

      const alice = findNode(sim, "alice");
      const bob = findNode(sim, "bob");
      expect(alice.y).toBeLessThan(CENTER_Y);
      expect(bob.y).toBeLessThan(CENTER_Y);
    });

    it("simulation is deterministic for same inputs", () => {
      const makeNodes = () => [
        makeNode("claude", "claude"),
        makeNode("you", "you"),
        makeNode("alice", "other"),
        makeNode("bob", "other"),
      ];

      const sim1 = createStageSimulation(makeNodes(), CANVAS_W, CANVAS_H);
      runToCompletion(sim1);

      const sim2 = createStageSimulation(makeNodes(), CANVAS_W, CANVAS_H);
      runToCompletion(sim2);

      for (const n1 of sim1.nodes()) {
        const n2 = findNode(sim2, n1.id);
        expect(n1.x).toBeCloseTo(n2.x, 5);
        expect(n1.y).toBeCloseTo(n2.y, 5);
      }
    });

    it("2 people form a vertical line with realistic dimensions", () => {
      const nodes = [
        makeNode("claude", "claude", 180, 78),
        makeNode("you", "you", 288, 75),
        makeNode("alice", "other", 180, 63),
      ];
      const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
      runToCompletion(sim);

      const claude = findNode(sim, "claude");
      const you = findNode(sim, "you");
      const alice = findNode(sim, "alice");

      // Vertical order: alice < claude < you
      expect(alice.y).toBeLessThan(claude.y);
      expect(claude.y).toBeLessThan(you.y);
      // All near horizontal center
      expect(Math.abs(you.x - CENTER_X)).toBeLessThan(10);
      expect(Math.abs(alice.x - CENTER_X)).toBeLessThan(10);
    });
  });

  describe("boundary conditions", () => {
    it("zero other nodes - your card and claude still positioned", () => {
      const nodes = [makeNode("claude", "claude"), makeNode("you", "you")];
      const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
      runToCompletion(sim);

      const claude = findNode(sim, "claude");
      const you = findNode(sim, "you");
      expect(claude.x).toBe(CENTER_X);
      expect(claude.y).toBe(CENTER_Y);
      expect(you.y).toBeGreaterThan(CENTER_Y);
    });

    it("many other nodes (10+) - all remain within canvas bounds", () => {
      const nodes = [
        makeNode("claude", "claude"),
        makeNode("you", "you"),
        ...Array.from({ length: 12 }, (_, i) =>
          makeNode(`user-${i}`, "other", 30, 30)
        ),
      ];
      const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
      runToCompletion(sim);

      for (const node of sim.nodes()) {
        if (node.role === "claude") continue;
        expect(node.x).toBeGreaterThanOrEqual(node.halfW);
        expect(node.x).toBeLessThanOrEqual(CANVAS_W - node.halfW);
        expect(node.y).toBeGreaterThanOrEqual(node.halfH);
        expect(node.y).toBeLessThanOrEqual(CANVAS_H - node.halfH);
      }
    });

    it("nodes with large dimensions still fit within bounds", () => {
      const nodes = [
        makeNode("claude", "claude", 80, 80),
        makeNode("you", "you", 100, 50),
        makeNode("alice", "other", 90, 45),
      ];
      const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
      runToCompletion(sim);

      for (const node of sim.nodes()) {
        if (node.role === "claude") continue;
        expect(node.x).toBeGreaterThanOrEqual(node.halfW);
        expect(node.x).toBeLessThanOrEqual(CANVAS_W - node.halfW);
        expect(node.y).toBeGreaterThanOrEqual(node.halfH);
        expect(node.y).toBeLessThanOrEqual(CANVAS_H - node.halfH);
      }
    });
  });

  describe("update/reheat", () => {
    it("adding a new node and rebuilding settles correctly", () => {
      const nodes = [
        makeNode("claude", "claude"),
        makeNode("you", "you"),
        makeNode("alice", "other"),
      ];
      const sim1 = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
      runToCompletion(sim1);

      // Add bob, preserve alice's position
      const alice = findNode(sim1, "alice");
      const newNodes = [
        makeNode("claude", "claude"),
        makeNode("you", "you"),
        { id: "alice", role: "other", halfW: 40, halfH: 40, x: alice.x, y: alice.y },
        makeNode("bob", "other"),
      ];
      const sim2 = createStageSimulation(newNodes, CANVAS_W, CANVAS_H);
      runToCompletion(sim2);

      // Both others should settle above center
      const aliceAfter = findNode(sim2, "alice");
      const bob = findNode(sim2, "bob");
      expect(aliceAfter.y).toBeLessThan(CENTER_Y);
      expect(bob.y).toBeLessThan(CENTER_Y);
    });

    it("removing a node reheats and remaining nodes re-settle", () => {
      const nodes = [
        makeNode("claude", "claude"),
        makeNode("you", "you"),
        makeNode("alice", "other"),
        makeNode("bob", "other"),
      ];
      const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
      runToCompletion(sim);

      const remaining = sim.nodes().filter((n) => n.id !== "bob");
      sim.nodes(remaining);
      sim.alpha(0.3).restart();
      runToCompletion(sim);

      expect(sim.nodes().length).toBe(3);
      const alice = findNode(sim, "alice");
      expect(alice.x).toBeDefined();
      expect(alice.y).toBeDefined();
    });
  });
});

describe("clampToBounds", () => {
  it("clamps nodes within canvas bounds respecting halfW/halfH", () => {
    const nodes = [
      { id: "a", role: "other", halfW: 40, halfH: 30, x: -50, y: -50 },
      { id: "b", role: "other", halfW: 40, halfH: 30, x: 1050, y: 750 },
    ];
    clampToBounds(nodes, CANVAS_W, CANVAS_H);

    expect(nodes[0].x).toBeGreaterThanOrEqual(40);
    expect(nodes[0].y).toBeGreaterThanOrEqual(30);
    expect(nodes[1].x).toBeLessThanOrEqual(960);
    expect(nodes[1].y).toBeLessThanOrEqual(670);
  });

  it("does not clamp claude (fixed node)", () => {
    const nodes = [{ id: "claude", role: "claude", halfW: 50, halfH: 50, x: 500, y: 350, fx: 500, fy: 350 }];
    clampToBounds(nodes, CANVAS_W, CANVAS_H);

    expect(nodes[0].x).toBe(500);
    expect(nodes[0].y).toBe(350);
  });
});

describe("pinWinner", () => {
  it("winner node gets pinned to center via fx/fy", () => {
    const nodes = [
      makeNode("claude", "claude"),
      makeNode("you", "you"),
      makeNode("alice", "other"),
    ];
    const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
    runToCompletion(sim);

    pinWinner(sim, "alice", CENTER_X, CENTER_Y);
    runToCompletion(sim);

    const alice = findNode(sim, "alice");
    expect(alice.fx).toBe(CENTER_X);
    expect(alice.fy).toBe(CENTER_Y);
    expect(alice.x).toBe(CENTER_X);
    expect(alice.y).toBe(CENTER_Y);
  });

  it("claude can be the winner", () => {
    const nodes = [
      makeNode("claude", "claude"),
      makeNode("you", "you"),
      makeNode("alice", "other"),
    ];
    const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
    runToCompletion(sim);

    pinWinner(sim, "claude", CENTER_X, CENTER_Y);

    const claude = findNode(sim, "claude");
    expect(claude.fx).toBe(CENTER_X);
    expect(claude.fy).toBe(CENTER_Y);
  });

  it("loser nodes are not pinned", () => {
    const nodes = [
      makeNode("claude", "claude"),
      makeNode("you", "you"),
      makeNode("alice", "other"),
      makeNode("bob", "other"),
    ];
    const sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
    runToCompletion(sim);

    pinWinner(sim, "alice", CENTER_X, CENTER_Y);

    const bob = findNode(sim, "bob");
    const you = findNode(sim, "you");
    expect(bob.fx).toBeUndefined();
    expect(you.fx).toBeUndefined();
  });
});
