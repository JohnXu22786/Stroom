import 'package:flutter/material.dart';

/// Describes a mermaid diagram type with display info
class MermaidDiagramType {
  final String id;
  final String label;
  final IconData icon;
  final String description;
  /// 用于从代码首行检测图表类型的关键字
  final String keyword;

  const MermaidDiagramType({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    required this.keyword,
  });
}

/// Template generators for all mermaid.js diagram types.
///
/// Each method returns a complete, valid mermaid code snippet that the
/// user can immediately preview and customise.
class MermaidTemplates {
  MermaidTemplates._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the [MermaidDiagramType] list (all supported types).
  static List<MermaidDiagramType> getAllTypes() => _types;

  /// Returns a template string for the given [typeId].
  /// Returns empty string if the type is unknown.
  static String getTemplate(String typeId) {
    final generator = _generators[typeId];
    if (generator == null) return '';
    return generator();
  }

  /// Inserts a [snippet] (e.g. a new node/edge) into existing mermaid [code].
  /// Appends the snippet on a new line.
  static String insertSnippet(String code, String snippet) {
    if (code.trim().isEmpty) return snippet;
    final buf = StringBuffer(code.trimRight());
    buf.writeln();
    buf.write(snippet);
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Diagram type metadata
  // ---------------------------------------------------------------------------

  static const _types = <MermaidDiagramType>[
    MermaidDiagramType(
      id: 'flowchart',
      label: '流程图',
      icon: Icons.account_tree,
      description: '流程图 — 展示步骤、分支与循环',
      keyword: 'graph',
    ),
    MermaidDiagramType(
      id: 'sequenceDiagram',
      label: '时序图',
      icon: Icons.swap_vert,
      description: '时序图 — 展示对象之间的交互顺序',
      keyword: 'sequenceDiagram',
    ),
    MermaidDiagramType(
      id: 'classDiagram',
      label: '类图',
      icon: Icons.category,
      description: '类图 — 展示类的属性与方法关系',
      keyword: 'classDiagram',
    ),
    MermaidDiagramType(
      id: 'stateDiagram',
      label: '状态图',
      icon: Icons.loop,
      description: '状态图 — 展示状态流转',
      keyword: 'stateDiagram',
    ),
    MermaidDiagramType(
      id: 'erDiagram',
      label: 'ER图',
      icon: Icons.hub,
      description: 'ER图 — 展示实体关系',
      keyword: 'erDiagram',
    ),
    MermaidDiagramType(
      id: 'gantt',
      label: '甘特图',
      icon: Icons.bar_chart,
      description: '甘特图 — 展示项目时间线',
      keyword: 'gantt',
    ),
    MermaidDiagramType(
      id: 'pie',
      label: '饼图',
      icon: Icons.pie_chart,
      description: '饼图 — 展示占比数据',
      keyword: 'pie',
    ),
    MermaidDiagramType(
      id: 'journey',
      label: '用户旅程图',
      icon: Icons.route,
      description: '用户旅程图 — 展示用户体验流程',
      keyword: 'journey',
    ),
    MermaidDiagramType(
      id: 'gitGraph',
      label: 'Git分支图',
      icon: Icons.call_split,
      description: 'Git分支图 — 展示Git分支与提交',
      keyword: 'gitGraph',
    ),
    MermaidDiagramType(
      id: 'mindmap',
      label: '思维导图',
      icon: Icons.psychology,
      description: '思维导图 — 展示层级结构',
      keyword: 'mindmap',
    ),
    MermaidDiagramType(
      id: 'timeline',
      label: '时间线',
      icon: Icons.timeline,
      description: '时间线 — 按时间顺序展示事件',
      keyword: 'timeline',
    ),
    MermaidDiagramType(
      id: 'block',
      label: '块图',
      icon: Icons.grid_view,
      description: '块图 — 展示块级布局与关系',
      keyword: 'block-beta',
    ),
    MermaidDiagramType(
      id: 'requirement',
      label: '需求图',
      icon: Icons.checklist,
      description: '需求图 — 展示需求与实现关系',
      keyword: 'requirementDiagram',
    ),
  ];

  // ---------------------------------------------------------------------------
  // Template generators (keyed by typeId)
  // ---------------------------------------------------------------------------

  static final Map<String, String Function()> _generators = {
    'flowchart': _flowchartTemplate,
    'sequenceDiagram': _sequenceDiagramTemplate,
    'classDiagram': _classDiagramTemplate,
    'stateDiagram': _stateDiagramTemplate,
    'erDiagram': _erDiagramTemplate,
    'gantt': _ganttTemplate,
    'pie': _pieTemplate,
    'journey': _journeyTemplate,
    'gitGraph': _gitGraphTemplate,
    'mindmap': _mindmapTemplate,
    'timeline': _timelineTemplate,
    'block': _blockTemplate,
    'requirement': _requirementTemplate,
  };

  static String _flowchartTemplate() {
    return '''graph TD
  A[开始]
  B[处理步骤]
  C{判断条件}
  D[结束]

  A --> B
  B --> C
  C -->|是| D
  C -->|否| B''';
  }

  static String _sequenceDiagramTemplate() {
    return '''sequenceDiagram
  participant 用户
  participant 系统
  participant 数据库

  用户->>系统: 发送请求
  系统->>数据库: 查询数据
  数据库-->>系统: 返回结果
  系统-->>用户: 显示结果''';
  }

  static String _classDiagramTemplate() {
    return '''classDiagram
  class Person {
    +String name
    +int age
    +getName() String
    +setName(String name) void
  }
  class Student {
    +String studentId
    +study() void
  }
  class Teacher {
    +String teacherId
    +teach() void
  }
  Student --|> Person
  Teacher --|> Person''';
  }

  static String _stateDiagramTemplate() {
    return '''stateDiagram-v2
  [*] --> 待处理
  待处理 --> 处理中
  处理中 --> 已完成
  处理中 --> 失败
  失败 --> 待处理
  已完成 --> [*]''';
  }

  static String _erDiagramTemplate() {
    return '''erDiagram
  CUSTOMER ||--o{ ORDER : places
  ORDER ||--|{ ORDER_ITEM : contains
  PRODUCT ||--o{ ORDER_ITEM : includes
  CUSTOMER {
    int id PK
    string name
    string email
  }
  ORDER {
    int id PK
    int customer_id FK
    date order_date
  }
  PRODUCT {
    int id PK
    string name
    float price
  }''';
  }

  static String _ganttTemplate() {
    return '''gantt
  title 项目甘特图
  dateFormat  YYYY-MM-DD
  axisFormat  %m/%d

  section 需求阶段
  需求分析     :a1, 2024-01-01, 14d
  原型设计     :a2, after a1, 10d

  section 开发阶段
  前端开发     :b1, after a2, 20d
  后端开发     :b2, after a2, 20d
  接口联调     :b3, after b1, 7d

  section 测试阶段
  功能测试     :c1, after b3, 10d
  部署上线     :c2, after c1, 3d''';
  }

  static String _pieTemplate() {
    return '''pie showData
  title 数据分布
  "类别A" : 40
  "类别B" : 25
  "类别C" : 20
  "类别D" : 15''';
  }

  static String _journeyTemplate() {
    return '''journey
  title 用户注册流程
  section 注册页面
    打开注册页: 5: 用户
    填写信息: 3: 用户
    提交申请: 4: 用户
  section 验证阶段
    接收验证码: 3: 系统
    输入验证码: 4: 用户
    验证成功: 5: 系统, 用户''';
  }

  static String _gitGraphTemplate() {
    return '''gitGraph
  commit id: "初始提交"
  commit id: "添加功能A"
  branch develop
  checkout develop
  commit id: "开发新功能"
  commit id: "修复bug"
  checkout main
  merge develop
  commit id: "发布v1.0"''';
  }

  static String _mindmapTemplate() {
    return '''mindmap
  root((项目管理))
    需求
      功能需求
      非功能需求
    开发
      前端
      后端
    测试
      单元测试
      集成测试
    部署
      测试环境
      生产环境''';
  }

  static String _timelineTemplate() {
    return '''timeline
  title 项目里程碑
  2024-Q1 : 需求调研 : 方案确定
  2024-Q2 : 开发阶段 : 功能实现
  2024-Q3 : 测试阶段 : Bug修复 : 性能优化
  2024-Q4 : 部署上线 : 运营维护''';
  }

  static String _blockTemplate() {
    return '''block-beta
  columns 3
  A["需求"] B["开发"] C["测试"]
  D["部署"] E["运维"] F["监控"]
  A --> B
  B --> C
  C --> D
  D --> E
  E --> F''';
  }

  static String _requirementTemplate() {
    return '''requirementDiagram
  requirement 用户登录 {
    id: 1
    text: 用户能够使用账号密码登录系统
    risk: medium
    verifiedMethod: test
  }
  element 登录页面 {
    type: UI
  }
  element 认证服务 {
    type: Service
  }
  用户登录 - satisfies - 登录页面
  用户登录 - verifiedBy - 认证服务''';
  }

  // ---------------------------------------------------------------------------
  // Context-specific snippets for each diagram type
  // ---------------------------------------------------------------------------

  /// Returns a list of "snippet buttons" for a given diagram [typeId].
  /// Each entry is (label, snippetText).
  static List<(String label, String snippet)> getSnippets(String typeId) {
    switch (typeId) {
      case 'flowchart':
        return [
          ('添加节点', '  NewNode[新节点]'),
          ('添加菱形判断', '  Condition{判断条件}'),
          ('添加连接线', '  Node1 --> Node2'),
          ('添加子图', 'subgraph 子图名称\n  Node1[节点1]\nend'),
        ];
      case 'sequenceDiagram':
        return [
          ('添加参与者', 'participant 新参与者'),
          ('添加请求', 'A->>B: 请求消息'),
          ('添加响应', 'B-->>A: 响应消息'),
          ('添加备注', 'Note over A,B: 备注内容'),
        ];
      case 'classDiagram':
        return [
          ('添加类', 'class 新类 {\n  +String 属性\n  +方法() void\n}'),
          ('添加继承', '子类 --|> 父类'),
          ('添加关联', '类A --> 类B'),
          ('添加聚合', '整体 o-- 部分'),
        ];
      case 'stateDiagram':
        return [
          ('添加状态', '  新状态'),
          ('添加转换', '  状态1 --> 状态2'),
          ('添加开始', '  [*] --> 初始状态'),
          ('添加结束', '  最终状态 --> [*]'),
        ];
      case 'erDiagram':
        return [
          ('添加实体', '  新实体 {\n    int id PK\n    string name\n  }'),
          ('添加一对多', '  实体A ||--o{ 实体B : 拥有'),
          ('添加多对多', '  实体A }o--o{ 实体B : 关联'),
          ('添加一对一', '  实体A ||--|| 实体B : 对应'),
        ];
      case 'gantt':
        return [
          ('添加阶段', '  section 新阶段'),
          ('添加任务', '  新任务 :2024-01-01, 7d'),
          ('添加依赖任务', '  后续任务 :after 前序任务, 5d'),
          ('添加里程碑', '  里程碑 :milestone, 2024-01-15, 0d'),
        ];
      case 'pie':
        return [
          ('添加类别', '  "新类别" : 30'),
          ('添加标题', 'title 饼图标题'),
        ];
      case 'journey':
        return [
          ('添加阶段', '  section 新阶段'),
          ('添加任务', '    新任务: 3: 用户'),
          ('添加系统任务', '    系统处理: 5: 系统'),
          ('添加多人任务', '    协作任务: 4: 用户, 系统'),
        ];
      case 'gitGraph':
        return [
          ('添加提交', '  commit id: "新提交"'),
          ('创建分支', '  branch 新分支'),
          ('切换分支', '  checkout 新分支'),
          ('合并分支', '  merge 当前分支'),
        ];
      case 'mindmap':
        return [
          ('添加分支', '    新分支'),
          ('添加子分支', '      子分支'),
          ('添加根节点', '  root((新主题))'),
        ];
      case 'timeline':
        return [
          ('添加时间段', '  2024-Q1 : 事件1 : 事件2'),
          ('添加标题', 'title 时间线标题'),
        ];
      case 'block':
        return [
          ('添加块', '  NewBlock["新块"]'),
          ('添加列', '  columns 3'),
          ('添加连接', '  A --> B'),
          ('添加子块', '  block\n    A["块A"]\n  end'),
        ];
      case 'requirement':
        return [
          ('添加需求', '  requirement 新需求 {\n    id: 1\n    text: 需求描述\n  }'),
          ('添加元素', '  element 新元素 {\n    type: UI\n  }'),
          ('添加关联', '  需求A - satisfies - 元素B'),
          (
            '添加验证',
            '  需求A - verifiedBy - 元素B',
          ),
        ];
      default:
        return [];
    }
  }
}
