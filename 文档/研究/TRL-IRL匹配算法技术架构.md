# TRL/IRL 匹配算法技术架构设计

> **文档类型**：技术架构设计（数据底座架构师视角）  
> **适用产品**：LinkedEvery 智能体中台（导师-企业精准匹配引擎）  
> **创建日期**：2026-06-16  
> **版本**：v1.0  
> **状态**：初稿（可进入技术评审）  
> **设计原则**：先跑通 MVP，再逐步引入向量检索、机器学习与自动蒸馏能力

---

## 0. 设计摘要

本文件从**数据底座架构师（小天）**的视角，完成以下四项设计：

1. **TRL/IRL 数据模型设计**：导师能力、企业成熟度、匹配记录、评估记录四类核心实体模型  
2. **匹配算法架构设计**：六维度加权匹配、候选筛选、多样性优化、冷启动方案  
3. **数据采集方案**：必填字段、校验规则、质量控制（QC）与运营闭环  
4. **技术实现路径**：推荐技术栈、核心 API、数据库 ER 图、系统架构图  

### 核心结论

- **先做规则引擎 + 解释性评分**，确保匹配结果可解释、可复盘、可运营干预  
- **匹配策略遵循“诊断→处方→配药”模型**，即先识别企业需求等级（L1-L4），再匹配导师能力带（TRL）  
- **数据底座优先建设可审计数据链**：证据字段（来源、时间、置信度）与评分字段必须分离  
- **冷启动以“需求池反向拉动 + 人工兜底”为主**，算法先保证召回与可解释，再追求排序精度  

---

## 1. TRL/IRL 数据模型设计

### 1.1 模型设计原则

1. **证据与评分分离**：所有量化得分（如 `trl_score`）必须可追溯到证据字段（如 `evidence.publications`）  
2. **时间感知**：每个能力/成熟度快照必须带 `assessed_at`、`expires_at`，支持定期复评  
3. **多版本画像并存**：支持“自评、系统评估、人工复核”多版本画像，最终匹配使用 `effective_profile`  
4. **面向匹配可解释**：模型中必须保留可直接用于匹配解释的“可读特征”（如 `primary_industry_tags`）  

### 1.2 导师 TRL 数据结构设计

#### 1.2.1 设计目标

将导师 TRL 定义为**“导师对企业可提供的指导成熟度带宽”**，而不是单纯学术水平。  
结合现有成熟度框架，评估维度拆为：**学术证据、技术证据、工程证据、产业证据**。

#### 1.2.2 导师主数据结构（MentorProfile）

```json
{
  "mentor_id": "mnt_20260616_0001",
  "version": 3,
  "status": "ACTIVE",
  "basic": {
    "name": "刘银华",
    "gender": "MALE",
    "title": "硕士生导师",
    "org": "上海理工大学 机械工程学院",
    "city": "上海",
    "primary_domains": ["智能制造", "机器视觉", "工业机器人"],
    "cdio_roles": ["CTO", "CDO"],
    "available_service_modes": ["咨询", "方案评审", "陪跑", "培训"],
    "contact_channel_preferences": ["微信", "飞书"]
  },
  "trl": {
    "level": 6,
    "confidence": 0.78,
    "assessed_at": "2026-06-16T10:00:00+08:00",
    "expires_at": "2026-12-16T10:00:00+08:00",
    "score_breakdown": {
      "academic": 0.82,
      "technical": 0.80,
      "engineering": 0.74,
      "industrial": 0.62
    }
  },
  "evidence": {
    "academic": {
      "degree": "博士",
      "research_fields": ["机器视觉", "数字孪生", "AGV调度"],
      "publications_total": 25,
      "representative_publications": [
        {"title": "工业机器人路径规划优化算法", "year": 2023, "venue": "自动化学报", "citation": 18}
      ],
      "projects": [
        {"name": "上海市智能制造专项", "role": "主持", "budget_cny": 500000},
        {"name": "国家自然科学基金青年项目", "role": "主持", "budget_cny": 250000}
      ],
      "software_copyrights": 3,
      "verification_sources": ["知网", "基金委", "院校官网"]
    },
    "technical": {
      "tech_stack": ["Python", "C++", "OpenCV", "PyTorch"],
      "depth_level": "高级",
      "project_count": 20,
      "solution_cases": ["机器视觉质检系统", "机器人轨迹优化方案"],
      "certifications": []
    },
    "engineering": {
      "work_years": 12,
      "team_management_years": 6,
      "max_team_size": 15,
      "industry_exp": ["智能制造", "装备制造"],
      "delivery_cases": ["产学研项目试点", "产线仿真平台搭建"]
    },
    "industrial": {
      "industry_position": "专家",
      "resource_network_level": "区域",
      "entrepreneurial_experience": "无",
      "investor_network_level": "普通",
      "standard_or_publication_influence": "中"
    }
  },
  "matching_features": {
    "best_guidance_bands": [
      {"requirement_level": "L3", "ideal_irl_range": [2, 4]},
      {"requirement_level": "L4", "ideal_irl_range": [1, 2]}
    ],
    "good_at_phases": ["T2数字化期", "T3集成化期", "T4智能化期"],
    "good_at_industries": ["智能制造", "装备制造", "工业机器人"],
    "preferred_engagement_length_months": [1, 6],
    "service_capacity_per_quarter": 3
  },
  "meta": {
    "created_by": "system/manual",
    "last_reviewed_by": "ops_xiaojiao",
    "last_reviewed_at": "2026-06-16T10:00:00+08:00"
  }
}
```

#### 1.2.3 导师 TRL 评分规则（建议）

| 维度 | 可用证据示例 | 评分关注点 |
|---|---|---|
| 学术证据 | 学历、论文、项目、专利、基金 | 是否具备方法论基础和研究深度 |
| 技术证据 | 技术栈、解决方案、项目数、认证 | 是否具备可迁移技术能力 |
| 工程证据 | 工作年限、团队管理、交付案例 | 是否能把技术落到业务场景 |
| 产业证据 | 行业地位、资源网络、创业/投融资经验 | 是否具备产业连接和规模化视角 |

### 1.3 企业 IRL 数据结构设计

#### 1.3.1 设计目标

企业 IRL 定义为**“企业吸收、集成、持续运营某类技术能力的成熟度”**。  
采用五维度结构：**IT基础设施、数据基础、团队能力、管理流程、预算资源**。

#### 1.3.2 企业主数据结构（EnterpriseProfile）

```json
{
  "enterprise_id": "ent_20260616_0011",
  "version": 2,
  "status": "ACTIVE",
  "basic": {
    "company_name": "上海XX智能装备有限公司",
    "city": "上海",
    "scale": "100-300人",
    "industry_tags": ["装备制造", "工业机器人"],
    "primary_contact": {"name": "张总", "role": "总经理", "channel": "微信"},
    "budget_level": "中"
  },
  "requirement": {
    "level": "L3",
    "question": "我们知道要做什么，但技术上搞不定",
    "request_type": "技术攻关",
    "description": "希望引入机器视觉质检，完成缺陷检测系统从方案到试点落地",
    "urgency": "HIGH",
    "expected_start": "2026-07-01",
    "expected_duration_months": 4,
    "preferred_service_modes": ["方案设计", "技术陪跑", "现场指导"]
  },
  "irl": {
    "level": 3,
    "confidence": 0.71,
    "assessed_at": "2026-06-16T10:00:00+08:00",
    "expires_at": "2026-12-16T10:00:00+08:00",
    "dimension_scores": {
      "infrastructure": 3.2,
      "data": 2.8,
      "team": 3.0,
      "process": 2.5,
      "budget": 3.0
    },
    "weighted_score": 2.94
  },
  "irl_dimensions": {
    "infrastructure": {
      "server": "云服务器",
      "network": "企业网络",
      "security": "防火墙",
      "ops": "监控告警"
    },
    "data": {
      "governance": "公司级",
      "quality": "基本规范",
      "security": "基础",
      "application": "分析"
    },
    "team": {
      "tech_team_size": 8,
      "management_level": "专业",
      "training_system": "技能培训",
      "innovation": "改进"
    },
    "process": {
      "project_mgmt": "规范",
      "quality_mgmt": "过程控制",
      "process_standard": "标准化",
      "risk_mgmt": "识别"
    },
    "budget": {
      "it_budget_cny": 1200000,
      "rd_budget_cny": 3000000,
      "talent_budget_cny": 1500000,
      "training_budget_cny": 600000
    }
  },
  "matching_features": {
    "current_stage": "试点实施",
    "target_stage": "规模推广",
    "preferred_mentor_guidance_range": ["T5", "T7"],
    "blockers": ["算法团队不足", "数据标注流程不规范"],
    "decision_making_speed_days": 10
  },
  "meta": {
    "created_by": "ops_xiaojiao",
    "last_reviewed_at": "2026-06-16T10:00:00+08:00"
  }
}
```

#### 1.3.3 企业 IRL 五维度说明

| 维度 | 权重（建议） | 评估目标 |
|---|---:|---|
| IT基础设施 | 25% | 是否具备可运行、可集成的基础设施 |
| 数据基础 | 25% | 是否具备可驱动智能应用的数据能力 |
| 团队能力 | 20% | 是否具备承接与沉淀能力的人才 |
| 管理流程 | 15% | 是否具备将技术成果固化为流程的能力 |
| 预算资源 | 15% | 是否具备持续投入与推进的资源保障 |

### 1.4 匹配记录数据结构设计（MatchRecord）

```json
{
  "match_id": "match_20260616_000101",
  "requirement_id": "req_20260616_0011",
  "mentor_id": "mnt_20260616_0001",
  "enterprise_id": "ent_20260616_0011",
  "created_at": "2026-06-16T10:20:00+08:00",
  "algorithm_version": "v1.0-rule-weight",
  "snapshot": {
    "mentor_trl": 6,
    "enterprise_irl": 3,
    "requirement_level": "L3",
    "distance": 3
  },
  "scores": {
    "trl_irl_adaptability": 0.83,
    "skill_alignment": 0.78,
    "industry_match": 0.90,
    "scale_fit": 0.72,
    "service_form_match": 0.80,
    "geo_time_fit": 0.88,
    "final_score": 0.823,
    "rank_in_batch": 1
  },
  "explanation": {
    "top_reasons": [
      "导师 TRL 与企业 IRL 形成 +3 的带教距离，符合 L3 技术型需求最佳区间",
      "机器视觉与智能制造方向高度匹配企业技术攻关主题",
      "上海本地导师，线下陪跑和现场支持效率更高"
    ],
    "constraints_satisfied": ["行业匹配", "服务形式匹配", "响应时效"],
    "constraints_failed": []
  },
  "lifecycle": {
    "status": "MATCHED",
    "timeline": [
      {"at": "2026-06-16T10:20:00+08:00", "event": "MATCH_CREATED"},
      {"at": "2026-06-16T10:25:00+08:00", "event": "MENTOR_NOTIFIED"},
      {"at": "2026-06-16T15:00:00+08:00", "event": "MENTOR_ACCEPTED"}
    ]
  },
  "feedback": {
    "mentor_feedback_id": "fb_m_001",
    "enterprise_feedback_id": "fb_e_001",
    "success_flag": true,
    "failure_reason_code": null
  }
}
```

#### 匹配状态机建议

```
CANDIDATE -> MATCHED -> NOTIFIED -> ACCEPTED -> INTRO -> IN_PROGRESS -> DELIVERED -> CLOSED
                                                         \-> CANCELLED / EXPIRED / FAILED
```

### 1.5 评估记录数据结构设计（AssessmentRecord）

```json
{
  "assessment_id": "assess_20260616_000091",
  "target_type": "ENTERPRISE",
  "target_id": "ent_20260616_0011",
  "version": 1,
  "assessor_type": "SELF+SYSTEM+MANUAL",
  "assessor_id": "ops_xiaojiao",
  "assessed_at": "2026-06-16T10:00:00+08:00",
  "framework": "IRL-FIVE-DIMENSION",
  "raw_inputs": {
    "questionnaire_version": "IRL-Q-2026Q2",
    "answers": [
      {"question_id": "Q6", "dimension": "data", "option": "公司级", "score": 3}
    ],
    "uploaded_evidence": ["evidence_doc_001"]
  },
  "computed_result": {
    "level": 3,
    "weighted_score": 2.94,
    "dimension_scores": {
      "infrastructure": 3.2,
      "data": 2.8,
      "team": 3.0,
      "process": 2.5,
      "budget": 3.0
    }
  },
  "manual_review": {
    "reviewed": true,
    "adjusted_level": 3,
    "adjustment_reason": "试点阶段具备一定数据与团队基础，但流程仍需补齐"
  },
  "data_quality": {
    "completeness": 0.92,
    "consistency_score": 0.88,
    "confidence": 0.71,
    "issues": ["部分预算数据为区间估计"]
  },
  "effective_flag": true
}
```

---

## 2. 匹配算法架构设计

### 2.1 业务对齐前提

匹配算法必须与现有业务定义一致：

- **需求等级**：L1 服务型、L2 工程型、L3 技术型、L4 研究型  
- **最佳带教距离**：导师 TRL 领先企业 IRL 1-2 级最佳，0-3 可接受  
- **核心理念**：不是“找相同”，而是“诊断→处方→配药”  

### 2.2 六维度匹配模型（权重设计）

| 维度 | 权重 | 说明 |
|---|---:|---|
| TRL/IRL 适配度 | 35% | 与需求等级、最佳带教距离直接相关 |
| 技能对齐度 | 25% | 导师技能与企业需求主题、CDIO能力、行业关键词匹配 |
| 行业匹配度 | 15% | 行业标签、子行业、产业链位置匹配 |
| 规模适配度 | 10% | 企业规模与导师服务方式、组织复杂度匹配 |
| 服务形式 | 10% | 陪跑/咨询/培训/方案评审等服务形式匹配 |
| 地域时间 | 5% | 城市、通勤、响应周期、项目时长匹配 |

### 2.3 匹配计算算法设计（含伪代码）

#### 2.3.1 总公式

```
final_score(M, E, R) =
    w1 * s_trl_irl(M, E, R)
  + w2 * s_skill(M, E, R)
  + w3 * s_industry(M, E)
  + w4 * s_scale(M, E)
  + w5 * s_service(M, E, R)
  + w6 * s_geo_time(M, E)

其中：
w1=0.35, w2=0.25, w3=0.15, w4=0.10, w5=0.10, w6=0.05
```

#### 2.3.2 各维度评分伪代码

```python
def score_trl_irl(mentor, enterprise, requirement):
    req_level = requirement.level          # L1/L2/L3/L4
    mentor_trl = mentor.trl.level
    enterprise_irl = enterprise.irl.level

    distance = mentor_trl - enterprise_irl
    ideal_min, ideal_max = ideal_distance_range(req_level)   # e.g., (1,3) for L3
    tol_min, tol_max = tolerance_distance_range(req_level)   # e.g., (1,4) for L3

    if ideal_min <= distance <= ideal_max:
        distance_score = 1.0
    elif tol_min <= distance <= tol_max:
        distance_score = 0.6 + 0.4 * (1 - abs(distance - mid(ideal_min, ideal_max)) / half_width(tol_min, tol_max))
    else:
        distance_score = penalty(distance, tol_min, tol_max)

    guidance_band_score = band_overlap(
        mentor.best_guidance_bands,
        requirement.level,
        enterprise.irl.level
    )

    trl_confidence = mentor.trl.confidence
    irl_confidence = enterprise.irl.confidence

    return 0.6 * distance_score + 0.3 * guidance_band_score + 0.1 * min(trl_confidence, irl_confidence)


def score_skill(mentor, enterprise, requirement):
    keyword_sim = jaccard(mentor.primary_domains, requirement.tech_keywords)
    cdio_overlap = role_overlap(mentor.cdio_roles, requirement.expected_cdio_roles)
    blocker_support = blocker_support_score(mentor.matching_features.good_at_phases, enterprise.matching_features.blockers)

    return 0.5 * keyword_sim + 0.3 * cdio_overlap + 0.2 * blocker_support


def score_industry(mentor, enterprise):
    exact = exact_tag_overlap(mentor.good_at_industries, enterprise.industry_tags)
    related = related_industry_graph_score(mentor.good_at_industries, enterprise.industry_tags)
    return 0.6 * exact + 0.4 * related


def score_scale(mentor, enterprise):
    scale_level = scale_bucket(enterprise.basic.scale)          # 小/中/大/超大
    fit = service_capacity_fit(mentor.matching_features.service_capacity_per_quarter, enterprise.requirement.urgency)
    org_complexity = complexity_penalty(scale_level, mentor.engineering.team_management_years)
    return 0.6 * fit + 0.4 * (1 - org_complexity)


def score_service(mentor, enterprise, requirement):
    mode_overlap = overlap(mentor.available_service_modes, requirement.preferred_service_modes)
    duration_fit = duration_fit(mentor.preferred_engagement_length_months, requirement.expected_duration_months)
    return 0.6 * mode_overlap + 0.4 * duration_fit


def score_geo_time(mentor, enterprise):
    city_match = 1.0 if mentor.basic.city == enterprise.basic.city else 0.6
    urgency_fit = urgency_responsiveness(enterprise.requirement.urgency, mentor.matching_features.service_capacity_per_quarter)
    return 0.5 * city_match + 0.5 * urgency_fit
```

#### 2.3.3 L1-L4 最佳距离区间建议

| 需求等级 | 最佳距离 | 可接受距离 |
|---|---|---|
| L4 研究型 | +2 ~ +4 | +2 ~ +5 |
| L3 技术型 | +1 ~ +3 | +1 ~ +4 |
| L2 工程型 | +1 ~ +2 | +1 ~ +3 |
| L1 服务型 | 0 ~ +2 | 0 ~ +3 |

### 2.4 候选筛选策略

建议采用“漏斗式筛选”：

1. **硬约束过滤（Must-pass）**
   - 导师状态为 `ACTIVE`
   - 企业需求状态为 `OPEN`
   - 服务形式存在交集
   - 无黑名单冲突

2. **行业/主题召回（Retrieval）**
   - 基于行业标签、技术关键词、CDIO角色召回 200-500 个候选导师
   - 若后续引入向量检索，可增加语义召回层

3. **粗排（Coarse Ranking）**
   - 使用低计算成本特征快速打分
   - 保留 Top 50

4. **精排（Fine Ranking）**
   - 运行完整六维度评分
   - 输出解释性特征与 Top 10 候选

5. **人工兜底校验**
   - 冷启动期：Top 3 必须人工确认
   - 成熟期：异常样本（置信度低/新导师/新行业）触发人工复核

### 2.5 多样性优化算法

为避免结果过于同质化，建议在精排后增加**多样性重排（MMR）**：

```python
def mmr_rerank(candidates, lambda_div=0.3, top_k=5):
    selected = []
    pool = candidates.copy()

    while len(selected) < top_k and pool:
        best = None
        best_value = -1

        for c in pool:
            relevance = c.final_score
            redundancy = max(similarity(c, s) for s in selected) if selected else 0.0
            mmr_score = (1 - lambda_div) * relevance - lambda_div * redundancy

            if mmr_score > best_value:
                best_value = mmr_score
                best = c

        selected.append(best)
        pool.remove(best)

    return selected
```

多样性来源建议：

- 导师类型多样性（学术型 / 技术型 / 产业型）
- 服务方式多样性（陪跑 / 咨询 / 培训）
- 地域多样性（本地优先，但保留远程专家）

### 2.6 冷启动处理方案

#### 2.6.1 导师冷启动

- **Level 0（无数据）**：人工访谈 + 协会推荐 + 公开数据补全  
- **Level 1（公开数据）**：基于论文、基金、专利自动评估 TRL  
- **Level 2（自评数据）**：导师填写画像问卷 + 证据材料  
- **Level 3（行为数据）**：基于历史匹配、交付、评价数据修正画像  

#### 2.6.2 企业冷启动

- **Level 0（电话需求）**：结构化需求模板录入，人工转化为需求等级  
- **Level 1（自评问卷）**：IRL 五维度问卷 + 企业上传基础材料  
- **Level 2（系统诊断）**：问卷 + 抽检 + 关键证据核查  
- **Level 3（合作反馈）**：项目过程中持续修正企业画像  

#### 2.6.3 匹配冷启动策略

1. 先做“**需求驱动的专家召回**”，再做排序  
2. MVP 阶段匹配结果**不做全自动推送**，先输出“算法建议 + 理由”，运营确认后触达  
3. 设置“**首周回灌机制**”：每完成一个匹配，强制反馈是否准确，用于快速修正权重  

---

## 3. 数据采集方案

### 3.1 导师端必填字段设计（四类证据链）

#### 3.1.1 学术证据

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| 最高学历 | 单选 | 是 | 博士/硕士/本科 |
| 研究方向标签 | 多选 | 是 | 平台标准标签 |
| 论文总数 | 数字 | 是 | 可分 SCI/EI/核心 |
| 代表性论文 | 文本列表 | 否 | 最多 5 篇 |
| 科研项目 | 文本列表 | 否 | 主持/参与角色 |
| 专利/软著数量 | 数字 | 否 | 发明/实用/软著 |
| 学术荣誉 | 文本 | 否 | 用于置信度提升 |

#### 3.1.2 技术证据

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| 技术栈 | 多选 | 是 | 平台标准标签 |
| 技术深度 | 单选 | 是 | 初级/中级/高级/专家 |
| 项目数量 | 数字 | 是 | 近 10 年相关项目 |
| 代表性方案 | 文本 | 否 | 可结构化输入 |
| 技术认证 | 多选 | 否 | 行业/厂商认证 |

#### 3.1.3 工程证据

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| 从业年限 | 数字 | 是 | 与主题相关年限 |
| 管理人数 | 数字 | 否 | 最大团队规模 |
| 交付案例 | 文本列表 | 否 | 项目名称 + 成果 |
| 行业经验 | 多选 | 是 | 制造/金融/医疗等 |
| 项目规模 | 单选 | 是 | 小型/中型/大型 |

#### 3.1.4 产业证据

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| 行业地位 | 单选 | 是 | 从业者/管理者/专家/领军人物 |
| 创业经历 | 单选 | 否 | 无/创始人/联合创始人/高管 |
| 投融资网络 | 单选 | 否 | 无/天使/VC/PE |
| 行业影响力 | 单选 | 否 | 普通/区域/全国/国际 |
| 可服务城市 | 多选 | 是 | 用于地域匹配 |

### 3.2 企业端必填字段设计（五维度评估）

| 维度 | 必填字段示例 |
|---|---|
| IT基础设施 | 服务器形态、网络、安全等级、运维方式 |
| 数据基础 | 数据治理层级、数据质量、数据应用 |
| 团队能力 | 技术团队规模、管理成熟度、培训体系 |
| 管理流程 | 项目管理、质量管理、流程规范 |
| 预算资源 | IT预算、研发预算、培训预算 |

企业需求侧必填字段：

| 字段 | 说明 |
|---|---|
| 需求等级 | L1/L2/L3/L4 |
| 需求描述 | 核心问题一句话 |
| 技术关键词 | 结构化标签 |
| 期望启动时间 | 可排期 |
| 预算范围 | 可选区间 |
| 服务形式偏好 | 陪跑/咨询/培训等 |

### 3.3 数据验证规则设计

#### 3.3.1 导师数据校验

| 规则 | 说明 |
|---|---|
| `publications_total >= 0` | 不能为负 |
| `work_years` 合理区间 | 0-50，超区间人工复核 |
| 研究方向必须来自标准标签库 | 避免自由文本导致匹配失败 |
| 代表性论文可公开验证 | 支持 URL / DOI / 期刊名交叉校验 |
| 服务形式必须与 TRL 区间一致 | 高级导师不能仅配置低级服务 |

#### 3.3.2 企业数据校验

| 规则 | 说明 |
|---|---|
| IRL 五维度必须完整 | 单维度缺失不可进入精排 |
| 需求等级与 IRL 不能严重冲突 | 如 IRL=L5 + 需求=L4 触发人工复核 |
| 预算字段支持区间输入 | 防止敏感数据暴露 |
| 城市、行业必填 | 否则地域与行业权重失效 |

### 3.4 数据质量控制方案

1. **采集层**
   - 表单默认值校验 + 实时提示
   - 必填字段强制阻断
   - 文本字段长度与格式约束

2. **入库层**
   - 数据标准化（城市、行业、服务形式统一字典）
   - 证据、评分、主数据分区存储
   - 变更历史可审计

3. **复核层**
   - 新导师首次画像自动进入人工审核队列
   - 置信度低于阈值的画像自动降权
   - 异常画像（如 TRL=9 但无交付证据）触发强复核

4. **运营层**
   - 每次匹配失败（企业拒绝/导师拒绝）记录原因码
   - 每月做画像准确率回测
   - 季度更新权重和校验规则

---

## 4. 技术实现路径

### 4.1 推荐技术栈

| 层级 | 推荐方案 | 说明 |
|---|---|---|
| 后端 | Python（FastAPI）/ Java（Spring Boot） | Python 更利于算法迭代，Java 更利于工程稳定性 |
| 数据库 | PostgreSQL + pgvector | 关系型存储 + 向量扩展一体化 |
| 缓存 | Redis | 候选集缓存、热门画像缓存 |
| 搜索/召回 | Elasticsearch 或 Postgres FTS | 结构化检索 + 标签检索 |
| 向量检索 | pgvector / Milvus（后续） | 支持语义召回 |
| 任务与调度 | Celery / Temporal | 异步匹配、回灌任务、批量评估 |
| 模型服务 | FastAPI / Triton（后续） | MVP 阶段规则引擎优先 |
| 前端 | React / Vue | 匹配工作台、画像工作台 |
| 数据集成 | Airbyte / 自研 ETL | 公开数据、协会数据、问卷数据采集 |

### 4.2 核心 API 设计

#### 4.2.1 导师画像 API

- `POST /api/v1/mentors` 创建导师主数据  
- `PUT /api/v1/mentors/{mentor_id}` 更新导师画像  
- `GET /api/v1/mentors/{mentor_id}` 获取导师画像  
- `POST /api/v1/mentors/{mentor_id}/assessments` 提交导师评估记录  

#### 4.2.2 企业画像与需求 API

- `POST /api/v1/enterprises` 创建企业主数据  
- `PUT /api/v1/enterprises/{enterprise_id}` 更新企业画像  
- `POST /api/v1/requirements` 创建企业需求  
- `GET /api/v1/requirements/{requirement_id}` 获取需求详情与 IRL 快照  

#### 4.2.3 匹配服务 API

- `POST /api/v1/matches/generate` 根据需求生成匹配候选  
- `GET /api/v1/matches/{match_id}` 获取匹配详情与解释  
- `POST /api/v1/matches/{match_id}/confirm` 运营/导师/企业确认匹配  
- `POST /api/v1/matches/{match_id}/feedback` 提交匹配反馈  
- `GET /api/v1/matches/batch-report` 匹配批次效果报表  

#### 4.2.4 管理与运营 API

- `GET /api/v1/analytics/funnel` 七节点漏斗统计  
- `GET /api/v1/analytics/quality` 数据质量报告  
- `GET /api/v1/reports/mentor/{mentor_id}` 导师画像报告  
- `GET /api/v1/reports/enterprise/{enterprise_id}` 企业画像报告  

### 4.3 数据库 ER 图设计（文本版）

```
MentorProfile (1) ──< MentorAssessment (N)
MentorProfile (1) ──< MentorEvidence (N)
MentorProfile (1) ──< MatchRecord (N)

EnterpriseProfile (1) ──< EnterpriseAssessment (N)
EnterpriseProfile (1) ──< Requirement (N)
Requirement (1) ──< MatchRecord (N)

MatchRecord (1) ──< MatchFeedback (0..2)   // mentor + enterprise
MatchRecord (1) ──< MatchTimelineEvent (N)

DictionaryIndustry (1) ──< Requirement (N)
DictionaryServiceMode (1) ──< Requirement (N)
```

#### 核心表建议

| 表 | 主键 | 说明 |
|---|---|---|
| `mentor_profile` | `mentor_id` | 导师主数据与当前有效画像 |
| `mentor_assessment` | `assessment_id` | 导师历史评估版本 |
| `enterprise_profile` | `enterprise_id` | 企业主数据 |
| `enterprise_assessment` | `assessment_id` | 企业 IRL 历史评估版本 |
| `requirement` | `requirement_id` | 企业需求 |
| `match_record` | `match_id` | 匹配记录 |
| `match_feedback` | `feedback_id` | 匹配反馈 |
| `dictionary_*` | `code` | 标准字典表 |

### 4.4 系统架构图设计（文本版）

```
+------------------------------+       +-----------------------------+
|          运营工作台          |       |         企业/导师端          |
+------------------------------+-------+-----------------------------+
                    |
                    v
          +-------------------+
          |   API Gateway     |
          +-------------------+
                    |
       +------------+------------+
       |                         |
       v                         v
+------------------+    +------------------+
|  画像与需求服务  |    |   匹配与排序服务  |
+------------------+    +------------------+
       |                         |
       v                         v
+------------------+    +------------------+
| PostgreSQL       |    | Redis / Search   |
| (主数据/评估/匹配)|    | (候选缓存/检索)  |
+------------------+    +------------------+
       |
       v
+------------------+
| 数据采集与ETL    |
| (问卷/公开数据)  |
+------------------+
```

---

## 5. 落地建议（优先级）

### 5.1 MVP（0-8周）

1. 完成导师、企业、需求、匹配四张核心表  
2. 上线结构化问卷与必填字段校验  
3. 实现规则版六维度评分 + 可解释 Top 3  
4. 建立人工确认与反馈回写闭环  

### 5.2 Phase 2（9-16周）

1. 增加向量检索召回层  
2. 增加画像置信度自动衰减与复评提醒  
3. 上线多样性重排与运营看板  
4. 接入公开数据源自动补全导师画像  

### 5.3 Phase 3（17-24周）

1. 引入匹配效果离线评估体系（Precision@K、NDCG、Match Success Rate）  
2. 引入轻量学习排序模型（LTR）替代部分手工权重  
3. 建立画像漂移检测与自动下线机制  
4. 支持跨区域、跨行业的扩展匹配策略  

---

## 附录 A：与现有方法论的映射

| 现有方法论 | 在本架构中的应用 |
|---|---|
| TRL 1-9 | 导师 TRL 评估与最佳带教距离计算 |
| IRL 五维度 | 企业成熟度评估与匹配输入 |
| L1-L4 需求等级 | 候选筛选与距离区间配置 |
| CDIO 能力体系 | 技能对齐度特征与导师定位 |
| 七节点运营闭环 | 匹配后状态机与效果回收 |

## 附录 B：关键指标建议

| 指标 | 定义 | 目标 |
|---|---|---|
| 首次匹配率 | Top 3 中至少 1 位被企业接受 | ≥ 60% |
| 匹配解释可用率 | 人工复核认可解释合理 | ≥ 85% |
| 画像完整率 | 必填字段完整占比 | ≥ 90% |
| 画像置信度均值 | 导师/企业画像平均置信度 | ≥ 0.70 |
| 反馈闭环率 | 匹配后回收到有效反馈比例 | ≥ 70% |

---

**文档维护责任**：数据底座架构师（小天）负责数据模型与算法接口；产品经理（小角）负责业务字段与运营流程对齐；技术负责人负责实现与性能优化。  
