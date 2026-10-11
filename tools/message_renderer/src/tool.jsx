import { useEffect, useState } from "react";
import { DisclosureRow, JsonTree } from "@deepseek-ai/dsh-client-ui-primitives";

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
  copyButtonTitle: (s) => s,
};

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
  return (
    <section className={`tool ${block.status}`}>
      <DisclosureRow
        title={block.name}
        icon={<span className="status-dot" />}
        open={open}
        expandable
        onToggle={() => setOpen((v) => !v)}
        expandOnRowClick
        running={block.status === "running"}
        collapsedContent={
          <span className="tool-status">
            {
              {
                completed: "完成",
                running: "执行中",
                pending: "等待",
                error: "失败",
              }[block.status]
            }
          </span>
        }
      >
        <div className="tool-detail">
          <h4>参数</h4>
          <JsonTree
            data={block.arguments || {}}
            label="工具参数"
            labels={labels}
          />
          {block.result != null && (
            <>
              <h4>{block.compactedAt ? "结果（已压缩）" : "结果"}</h4>
              {structured ? (
                <JsonTree data={parsed} label="工具结果" labels={labels} />
              ) : (
                <pre>{block.result}</pre>
              )}
            </>
          )}
        </div>
      </DisclosureRow>
    </section>
  );
}
