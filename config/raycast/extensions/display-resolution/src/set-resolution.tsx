import {
  Action,
  ActionPanel,
  Icon,
  List,
  Toast,
  closeMainWindow,
  showHUD,
  showToast,
} from "@raycast/api";
import { execSync } from "child_process";
import { useEffect, useState } from "react";

const DISPLAYPLACER = "/opt/homebrew/bin/displayplacer";
// これ未満の幅は一覧に出さない（低解像度モードのノイズ除去）
const MIN_WIDTH = 1920;

interface DisplayInfo {
  id: string;
  type: string;
  isMain: boolean;
  res: string;
  hz: string;
  scaling: string;
}

interface Mode {
  res: string;
  hz: string;
  scaling: boolean;
  width: number;
  height: number;
}

interface Parsed {
  main: DisplayInfo;
  subs: DisplayInfo[];
  mainModes: Mode[];
}

function parseList(): Parsed {
  const out = execSync(`${DISPLAYPLACER} list`, { encoding: "utf8" });
  const blocks = out.split("Persistent screen id: ").slice(1);

  const displays: DisplayInfo[] = [];
  let mainModes: Mode[] = [];

  for (const block of blocks) {
    const id = block.split("\n")[0].trim();
    const type = block.match(/^Type: (.+)$/m)?.[1] ?? "display";
    const res = block.match(/^Resolution: (\S+)/m)?.[1] ?? "";
    const hz = block.match(/^Hertz: (\S+)/m)?.[1] ?? "60";
    const scaling = block.match(/^Scaling: (\S+)/m)?.[1] ?? "off";
    const isMain = /^Origin: .* - main display$/m.test(block);
    displays.push({ id, type, isMain, res, hz, scaling });

    if (isMain) {
      // 同一解像度は HiDPI(scaling:on) を優先し1件にまとめる
      const byRes = new Map<string, Mode>();
      for (const m of block.matchAll(
        /mode \d+: res:(\d+)x(\d+) hz:(\d+) color_depth:\d+( scaling:on)?/g,
      )) {
        const [, w, h, mhz, sc] = m;
        if (mhz !== "60" || Number(w) < MIN_WIDTH) continue;
        const res = `${w}x${h}`;
        const existing = byRes.get(res);
        if (existing?.scaling) continue;
        byRes.set(res, {
          res,
          hz: mhz,
          scaling: Boolean(sc),
          width: Number(w),
          height: Number(h),
        });
      }
      mainModes = [...byRes.values()].sort((a, b) => b.width - a.width);
    }
  }

  const main = displays.find((d) => d.isMain);
  if (!main) throw new Error("メインディスプレイが見つからない");
  return { main, subs: displays.filter((d) => !d.isMain), mainModes };
}

function buildCommand(p: Parsed, mode: Mode): string {
  const parts = [
    `"id:${p.main.id} res:${mode.res} hz:${mode.hz} scaling:${mode.scaling ? "on" : "off"} origin:(0,0) degree:0"`,
  ];
  for (const sub of p.subs) {
    const subW = Number(sub.res.split("x")[0]);
    const x = Math.floor((mode.width - subW) / 2);
    parts.push(
      `"id:${sub.id} res:${sub.res} hz:${sub.hz} scaling:${sub.scaling} origin:(${x},${mode.height}) degree:0"`,
    );
  }
  return `${DISPLAYPLACER} ${parts.join(" ")}`;
}

export default function Command() {
  const [parsed, setParsed] = useState<Parsed | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    try {
      setParsed(parseList());
    } catch (e) {
      showToast({
        style: Toast.Style.Failure,
        title: "displayplacer 取得失敗",
        message: String(e),
      });
    } finally {
      setLoading(false);
    }
  }, []);

  async function apply(mode: Mode) {
    if (!parsed) return;
    try {
      execSync(buildCommand(parsed, mode));
      setParsed(parseList());
      await closeMainWindow();
      await showHUD(`✓ ${mode.res}${mode.scaling ? " HiDPI" : ""}`);
    } catch (e) {
      await showToast({
        style: Toast.Style.Failure,
        title: "解像度変更失敗",
        message: String(e),
      });
    }
  }

  const current = parsed?.main;

  return (
    <List isLoading={loading} searchBarPlaceholder="解像度を検索">
      {parsed?.mainModes.map((mode) => {
        const isCurrent =
          current?.res === mode.res &&
          (current?.scaling === "on") === mode.scaling;
        return (
          <List.Item
            key={`${mode.res}:${mode.scaling}`}
            icon={isCurrent ? Icon.CheckCircle : Icon.Monitor}
            title={mode.res}
            subtitle={mode.scaling ? "HiDPI" : "ネイティブ"}
            accessories={isCurrent ? [{ tag: "現在" }] : []}
            actions={
              <ActionPanel>
                <Action
                  title="適用（サブは中心揃え）"
                  icon={Icon.Monitor}
                  onAction={() => apply(mode)}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
