
import { describe, expect, it } from "vitest";
import { uintCV } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;

const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;

describe("sukuk_smart tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("allows subscription and redeems", () => {
    const { result: subResult } = simnet.callPublicFn("sukuk_smart", "subscribe-sukuk", [], wallet1);
    expect(subResult).toBeOk(uintCV(1));
    const { result: total } = simnet.callReadOnlyFn("sukuk_smart", "get-total-subscribed", [], wallet1);
    expect(total).toBeUint(1000000);
    simnet.mineEmptyBlock(20);
    const { result: redeemResult } = simnet.callPublicFn("sukuk_smart", "redeem", [], wallet1);
    expect(redeemResult).toBeOk(uintCV(1000000));
    const { result: totalAfter } = simnet.callReadOnlyFn("sukuk_smart", "get-total-subscribed", [], wallet1);
    expect(totalAfter).toBeUint(1000000);
  });
});
