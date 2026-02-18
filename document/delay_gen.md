# Delay Generator

Delay staging block that holds off an enable until a programmable number of reference clock cycles have elapsed. Countering occurs on `real_time_clk_i`, while enable release is synchronized to `clk_i`.

![Delay Generator](delay_gen.svg)

## Why this module is needed

- Many subsystems must stay idle for a few real-time cycles after reset so clocks, power rails, or PLLs can settle before enabling downstream logic.
- The delay counter lives in the real-time domain, while the enable is consumed in the local domain, so this block cleanly bridges the two clocks when they are synchronous/phase-aligned.
- By parameterizing `DELAY_CYCLES`, the warm-up duration can be tuned per instantiation without RTL edits.

## Interface

| Parameter      | Type | Default | Description                                                                                                                         |
| -------------- | ---- | ------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `DELAY_CYCLES` | int  | 10      | Number of `real_time_clk_i` cycles to wait before allowing `enable_o`. Counter width is $\lceil\log_2(\text{DELAY\_CYCLES})\rceil$. |

| Port              | Dir    | Clock           | Description                                                                     |
| ----------------- | ------ | --------------- | ------------------------------------------------------------------------------- |
| `arst_ni`         | input  | async           | Active-low asynchronous reset, shared by both domains.                          |
| `real_time_clk_i` | input  | real_time_clk_i | Reference clock used by the delay counter.                                      |
| `clk_i`           | input  | clk_i           | Local clock used to register `enable_o`.                                        |
| `enable_i`        | input  | clk_i           | Upstream enable request (sampled in `clk_i` domain).                            |
| `enable_o`        | output | clk_i           | Delayed enable, asserted once the counter completes and `enable_i` is asserted. |

Implementation: see [source/delay_gen.sv](source/delay_gen.sv#L15-L74).

## Behavior

- Reset drives `counter` and `enable_o` low. (both domains)
- `counter` increments on each `real_time_clk_i` rising edge while `counter != DELAY_CYCLES`; it saturates once done. [source/delay_gen.sv](source/delay_gen.sv#L55-L63)
- `counter_done` is combinationally true when `counter == DELAY_CYCLES`. [source/delay_gen.sv](source/delay_gen.sv#L47-L48)
- In the `clk_i` domain, when `enable_i` is high and `counter_done` is high, `enable_o` is set high and held until reset. [source/delay_gen.sv](source/delay_gen.sv#L65-L73)

**Latency:** `enable_o` can assert after `DELAY_CYCLES` rising edges of `real_time_clk_i` following reset deassertion, aligned to the next `clk_i` edge where `enable_i` is high.

## Reset and clocking considerations

- `arst_ni` is asynchronous; ensure deassertion meets recovery/removal for both clocks.
- `counter_done` crosses from `real_time_clk_i` into `clk_i` without explicit synchronization; use this module only when the clocks are synchronous/phase-aligned or when metastability risk is otherwise acceptable.
- `enable_o` does not auto-deassert when `enable_i` drops; reset is required to clear it.

## Usage example

```systemverilog
delay_gen #(
	.DELAY_CYCLES(32)
) u_delay_gen (
	.arst_ni         (arst_ni),
	.real_time_clk_i (rtc_clk),
	.clk_i           (core_clk),
	.enable_i        (init_done),
	.enable_o        (delayed_init_en)
);
```

## Integration checklist

- Confirm `real_time_clk_i` and `clk_i` relationship; add a two-flop sync for `counter_done` if clocks are asynchronous.
- Choose `DELAY_CYCLES` to cover the required post-reset warm-up budget.
- Verify downstream logic can tolerate sticky `enable_o` (cleared only by reset).
- Constrain CDC as needed if clocks differ.

## Test ideas

- Reset release followed by counting to `DELAY_CYCLES`; check `enable_o` asserts one `clk_i` edge after `enable_i` is high and `counter_done` is true.
- Vary `DELAY_CYCLES` (small, large) to confirm counter width scaling.
- Toggle `enable_i` before and after the delay to confirm sticky behavior.
- If clocks can drift, run randomized phase sweeps to catch CDC/metastability issues.
