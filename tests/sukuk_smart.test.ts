import { describe, expect, it } from "vitest";
import { uintCV } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;

describe("sukuk_smart tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("allows configure-sukuk by issuer", () => {
    const { result } = simnet.callPublicFn("sukuk_smart", "configure-sukuk", [uintCV(10000), uintCV(1000)], deployer);
    expect(result).toBeOk(uintCV(1));
  });

  it("allows subscription and redeem", () => {
    // First configure sukuk with high maturity block height
    simnet.callPublicFn("sukuk_smart", "configure-sukuk", [uintCV(10000), uintCV(1000)], deployer);
    
    const { result: subResult } = simnet.callPublicFn("sukuk_smart", "subscribe-sukuk", [], wallet1);
    expect(subResult).toBeOk(uintCV(1));
    const { result: total } = simnet.callReadOnlyFn("sukuk_smart", "get-total-subscribed", [], wallet1);
    expect(total).toBeUint(1000000);
    // Mine enough blocks to reach maturity
    simnet.mineEmptyBlock(10000);
    const { result: redeemResult } = simnet.callPublicFn("sukuk_smart", "redeem", [], wallet1);
    expect(redeemResult).toBeOk(uintCV(1000000));
    const { result: totalAfter } = simnet.callReadOnlyFn("sukuk_smart", "get-total-subscribed", [], wallet1);
    expect(totalAfter).toBeUint(1000000);
  });

  it("rejects configure-sukuk with past maturity", () => {
    const currentHeight = simnet.blockHeight;
    const { result } = simnet.callPublicFn("sukuk_smart", "configure-sukuk", [uintCV(currentHeight), uintCV(1000)], deployer);
    expect(result).toBeErr(uintCV(105));
  });

  it("rejects configure-sukuk by non-issuer", () => {
    const { result } = simnet.callPublicFn("sukuk_smart", "configure-sukuk", [uintCV(20000), uintCV(1000)], wallet1);
    expect(result).toBeErr(uintCV(100));
  });
});
