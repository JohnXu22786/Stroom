import { useEffect, useMemo, useState } from "react";
import {
  DisclosureRow,
  IconApiOutlineRegular,
  JsonTree,
  TextShimmer,
} from "@deepseek-ai/dsh-client-ui-primitives";

const labels = {
  copyValue: "复制值",
  copyJson: "复制 JSON",
  copyPath: "复制路径",
  copyPrettyJson: "复制格式化 JSON",
  copyCompactJson: "复制 JSON",
  copied: "已复制",
  copyFailed: "复制失败",
  collapseNode: "收起",
  expandNode: "展开",
  copyButtonTitle: (text) => text,
};

const statusText = {
  completed: "完成",
  running: "执行中",
  pending: "等待",
  error: "失败",
};

function firstLine(value) {
  if (value == null) return "";
  const text = typeof value === "string" ? value : JSON.stringify(value);
  return text?.split(/\r?\n/, 1)[0]?.trim() || "";
}

export function Tool({ block }) {
  const [open, setOpen] = useState(block.status === "error");
  useEffect(() => {
    if (block.status === "error") setOpen(true);
  }, [block.status]);

  let parsed;
  try {
    parsed = JSON.parse(block.result);
  } catch {}
  const structured = parsed !== null && typeof parsed === "object";
  const running = block.status === "running" || block.status === "pending";
  const summary = useMemo(
    () => firstLine(block.result) || statusText[block.status] || "",
    [block.result, block.status],
  );
  const argumentsValue = block.arguments || {};

  return (
    <div className="tool-row" data-state={block.status}>
      <DisclosureRow
        rowClassName="tool-disclosure"
        leadingClassName="tool-leading"
        titleClassName="tool-title"
        icon={<IconApiOutlineRegular size={14} />}
        title={block.name}
        running={running}
        open={open}
        expandable
        expandOnRowClick
        keepContentWhenOpen
        onToggle={() => setOpen((value) => !value)}
        collapsedContent={summary ? (
          <>
            <span className="tool-separator" data-shimmer-decoration aria-hidden />
            <span className={`tool-summary ${block.status === "error" ? "error" : ""}`}>
              <TextShimmer>{summary}</TextShimmer>
            </span>
          </>
        ) : undefined}
      >
        <div className="tool-detail">
          {Object.keys(argumentsValue).length > 0 && (
            <section className="tool-detail-section">
              <div className="tool-detail-label">参数</div>
              <JsonTree data={argumentsValue} label="工具参数" labels={labels} />
            </section>
          )}
          {block.result != null && (
            <section className="tool-detail-section">
              <div className="tool-detail-label">
                {block.compactedAt ? "结果（已压缩）" : "结果"}
              </div>
              {structured ? (
                <JsonTree data={parsed} label="工具结果" labels={labels} />
              ) : (
                <pre className={block.status === "error" ? "error" : ""}>
                  {block.result}
                </pre>
              )}
            </section>
          )}
        </div>
      </DisclosureRow>
    </div>
  );
}
