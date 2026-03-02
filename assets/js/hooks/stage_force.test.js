// @vitest-environment jsdom
import { describe, it, expect, beforeEach } from "vitest";
import { scanCards, mergeNodes } from "./stage_force";

function makeContainer(cards) {
  const container = document.createElement("div");
  for (const card of cards) {
    const el = document.createElement("div");
    el.setAttribute("data-node-id", card.id);
    el.setAttribute("data-node-role", card.role);
    // jsdom doesn't support offsetWidth/offsetHeight (returns 0),
    // so we mock them via properties
    Object.defineProperty(el, "offsetWidth", { value: card.width || 200 });
    Object.defineProperty(el, "offsetHeight", { value: card.height || 100 });
    container.appendChild(el);
  }
  return container;
}

describe("scanCards", () => {
  it("discovers elements with data-node-id", () => {
    const container = makeContainer([
      { id: "alice", role: "other" },
      { id: "claude", role: "claude" },
      { id: "you", role: "you" },
    ]);

    const result = scanCards(container);
    expect(result).toHaveLength(3);
    expect(result.map((n) => n.id).sort()).toEqual(["alice", "claude", "you"]);
  });

  it("reads data-node-role to assign role", () => {
    const container = makeContainer([
      { id: "alice", role: "other" },
      { id: "claude", role: "claude" },
      { id: "you", role: "you" },
    ]);

    const result = scanCards(container);
    const byId = Object.fromEntries(result.map((n) => [n.id, n]));

    expect(byId.alice.role).toBe("other");
    expect(byId.claude.role).toBe("claude");
    expect(byId.you.role).toBe("you");
  });

  it("computes halfW and halfH from offsetWidth/offsetHeight", () => {
    const container = makeContainer([
      { id: "alice", role: "other", width: 200, height: 100 },
    ]);

    const result = scanCards(container);
    expect(result[0].halfW).toBe(100);
    expect(result[0].halfH).toBe(50);
  });

  it("handles zero cards gracefully", () => {
    const container = document.createElement("div");
    const result = scanCards(container);
    expect(result).toHaveLength(0);
  });

  it("stores element reference on each node descriptor", () => {
    const container = makeContainer([{ id: "alice", role: "other" }]);
    const result = scanCards(container);
    expect(result[0].el).toBeInstanceOf(HTMLElement);
    expect(result[0].el.getAttribute("data-node-id")).toBe("alice");
  });
});

describe("mergeNodes", () => {
  it("preserves existing node positions on re-scan", () => {
    const existing = [
      { id: "alice", role: "other", halfW: 40, halfH: 30, x: 200, y: 150, vx: 1, vy: -1 },
      { id: "claude", role: "claude", halfW: 50, halfH: 50, x: 500, y: 350, fx: 500, fy: 350 },
    ];

    const scanned = [
      { id: "alice", role: "other", halfW: 45, halfH: 35, el: {} },
      { id: "claude", role: "claude", halfW: 50, halfH: 50, el: {} },
    ];

    const merged = mergeNodes(existing, scanned);
    const alice = merged.find((n) => n.id === "alice");

    expect(alice.x).toBe(200);
    expect(alice.y).toBe(150);
    expect(alice.vx).toBe(1);
    expect(alice.vy).toBe(-1);
    expect(alice.halfW).toBe(45); // updated from scan
    expect(alice.halfH).toBe(35); // updated from scan
    expect(alice.el).toBeDefined(); // updated element ref
  });

  it("detects new nodes vs existing nodes", () => {
    const existing = [
      { id: "alice", role: "other", halfW: 40, halfH: 30, x: 200, y: 150, vx: 0, vy: 0 },
    ];

    const scanned = [
      { id: "alice", role: "other", halfW: 40, halfH: 30, el: {} },
      { id: "bob", role: "other", halfW: 40, halfH: 30, el: {} },
    ];

    const merged = mergeNodes(existing, scanned);
    expect(merged).toHaveLength(2);

    const bob = merged.find((n) => n.id === "bob");
    expect(bob.x).toBeUndefined(); // new node, no position yet
  });

  it("drops nodes that are no longer in the scan", () => {
    const existing = [
      { id: "alice", role: "other", halfW: 40, halfH: 30, x: 200, y: 150, vx: 0, vy: 0 },
      { id: "bob", role: "other", halfW: 40, halfH: 30, x: 300, y: 250, vx: 0, vy: 0 },
    ];

    const scanned = [{ id: "alice", role: "other", halfW: 40, halfH: 30, el: {} }];

    const merged = mergeNodes(existing, scanned);
    expect(merged).toHaveLength(1);
    expect(merged[0].id).toBe("alice");
  });
});
