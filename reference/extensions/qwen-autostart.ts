// ABOUTME: Auto-starts llama-qwen.service when Pi switches to llama-local provider.
// ABOUTME: Eliminates manual systemctl start — Qwen loads to VRAM on model select.

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("model_select", async (event, ctx) => {
		// Only act when switching TO a llama-local model
		if (event.model.provider !== "llama-local") return;

		ctx.ui.notify("⚡ Loading Qwen to VRAM (~40s)...");

		try {
			// Start the service (uses existing sudoers: bzn NOPASSWD systemctl start/stop)
			const result = await pi.exec("sudo", ["systemctl", "start", "llama-qwen.service"]);
			if (result.exitCode !== 0) {
				ctx.ui.notify("❌ Failed to start Qwen");
				return;
			}

			// Wait for Qwen health — poll /v1/models
			for (let i = 0; i < 90; i++) {
				const check = await pi.exec("curl", [
					"-sf", "--max-time", "2",
					"http://100.64.144.126:11435/v1/models"
				]);
				if (check.exitCode === 0) {
					ctx.ui.notify("✅ Qwen loaded — ready");
					return;
				}
				await new Promise(r => setTimeout(r, 1000));
			}

			ctx.ui.notify("⚠️ Qwen may still be loading...");
		} catch (err) {
			ctx.ui.notify(`❌ Error: ${(err as Error).message}`);
		}
	});
}
