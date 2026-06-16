# TRL/IRL 匹配算法技术架构设计

> **文档类型**：技术架构设计（数据底座架构师视角）  
> **适用产品**：LinkedEvery 智能体中台（导师-企业精准匹配引擎）  
> **创建日期**：2026-06-16  
> **更新日期**：2026-06-16  
> **版本**：v2.0（整合15类型设计版）  
> **状态**：可进入技术评审  
> **设计原则**：先跑通 MVP，再逐步引入向量检索、机器学习与自动蒸馏能力

---

## 0. 设计摘要

本文件从**数据底座架构师（小天）**的视角，完成以下四项设计：

1. **TRL/IRL 数据模型设计**：导师能力、企业成熟度、匹配记录、评估记录四类核心实体模型  
2. **匹配算法架构设计**：六维度加权匹配、15个交叉点类型、候选筛选、多样性优化、冷启动方案  
3. **数据采集方案**：必填字段、校验规则、质量控制（QC）与运营闭环  
4. **技术实现路径**：推荐技术栈、核心 API、数据库 ER 图、系统架构图  

### 核心结论

- **先做规则引擎 + 解释性评分**，确保匹配结果可解释、可复盘、可运营干预  
- **匹配策略遵循"诊断→处方→配药"模型**，即先识别企业需求等级，再匹配15个交叉点类型  
- **15个类型实现精准匹配**：每个类型对应特定的TRL-IRL组合，实现更精准的导师-企业匹配
- **六维度匹配模型**：行业30% + 技能20% + TRL/IRL20% + 规模10% + 服务10% + 地域10%
- **数据底座优先建设可审计数据链**：证据字段（来源、时间、置信度）与评分字段必须分离  
- **冷启动以"需求池反向拉动 + 人工兜底"为主**，算法先保证召回与可解释，再追求排序精度  

---

## 1. TRL/IRL 数据模型设计

### 1.1 模型设计原则

1. **证据与评分分离**：所有量化得分（如 `trl_score`）必须可追溯到证据字段（如 `evidence.publications`）  
2. **时间感知**：每个能力/成熟度快照必须带 `assessed_at`、`expires_at`，支持定期复评  
3. **多版本画像并存**：支持"自评、系统评估、人工复核"多版本画像，最终匹配使用 `effective_profile`  
4. **面向匹配可解释**：模型中必须保留可直接用于匹配解释的"可读特征"（如 `primary_industry_tags`）  
5. **支持15个类型**：数据模型必须支持15个交叉点类型的匹配和展示

### 1.2 导师 TRL 数据结构设计

#### 1.2.1 设计目标

将导师 TRL 定义为**"导师对企业可提供的指导成熟度带宽"**，而不是单纯学术水平。  
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
  "matching_features": {
    "good_at_industries": ["装备制造", "汽车零部件", "3C电子"],
    "good_at_phases": ["工艺优化", "系统集成", "技术攻关"],
    "service_capacity_per_quarter": 3,
    "best_guidance_bands": ["T4-T7"],
    "typical_engagement_length_months": [2, 4, 6]
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
      "managed_team_size": 15,
      "project_scale": "大型",
      "industry_experience": ["装备制造", "汽车零部件"],
      "success_cases": [
        {"client": "某汽车零部件企业", "project": "智能质检系统", "duration_months": 6, "result": "缺陷检测准确率提升至99.2%"}
      ]
    },
    "industrial": {
      "industry_status": "专家",
      "resource_network": 50,
      "investment_experience": "天使",
      "entrepreneurial_experience": "技术合伙人",
      "industry_influence": "区域"
    }
  }
}
```

### 1.3 企业 IRL 数据结构设计

#### 1.3.1 设计目标

企业 IRL 定义为**"企业吸收、集成、持续运营某类技术能力的成熟度"**。  
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
  "matching_features": {
    "current_stage": "试点实施",
    "target_stage": "规模推广",
    "preferred_mentor_guidance_range": ["T5", "T7"],
    "blockers": ["算法团队不足", "数据标注流程不规范"],
    "decision_making_speed_days": 10
  }
}
```

### 1.4 匹配记录数据结构设计（MatchRecord）

```json
{
  "match_id": "match_20260616_000101",
  "requirement_id": "req_20260616_0011",
  "mentor_id": "mnt_20260616_0001",
  "enterprise_id": "ent_20260616_0011",
  "created_at": "2026-06-16T10:20:00+08:00",
  "algorithm_version": "v2.0-15types",
  "match_type": {
    "code": "⑥",
    "name": "工艺优化型",
    "trl_irl_combo": "T5-IRL3",
    "gap": 2,
    "description": "导师能做中试验证，企业已验证技术可行性"
  },
  "snapshot": {
    "mentor_trl": 5,
    "enterprise_irl": 3,
    "requirement_level": "L3",
    "distance": 2
  },
  "scores": {
    "industry_match": 0.95,
    "skill_alignment": 0.88,
    "trl_irl_adaptability": 0.82,
    "scale_fit": 0.78,
    "service_form_match": 0.85,
    "geo_time_fit": 0.90,
    "final_score": 0.823,
    "rank_in_batch": 1
  },
  "score_weights": {
    "industry": 0.30,
    "skill": 0.20,
    "trl_irl": 0.20,
    "scale": 0.10,
    "service": 0.10,
    "geo_time": 0.10
  },
  "explanation": {
    "match_type_reason": "导师TRL 5，企业IRL 3，差距2，属于工艺优化型最佳匹配区间",
    "top_reasons": [
      "张教授深耕制造业20年，与贵司行业高度匹配（权重30%）",
      "张教授在A3（技术开发）维度有丰富经验，匹配贵司技术需求（权重20%）",
      "张教授TRL 5，贵司IRL 3，处于最佳带教距离，属于工艺优化型（权重20%）",
      "张教授有中型企业服务经验，匹配贵司规模（权重10%）",
      "张教授可提供工艺优化服务，匹配贵司期望（权重10%）",
      "张教授在上海，与贵司同城，响应及时（权重10%）"
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

---

## 2. 匹配算法架构设计

### 2.1 业务对齐前提

匹配算法必须与现有业务定义一致：

- **需求等级**：L1 服务型、L2 工程型、L3 技术型、L4 研究型  
- **最佳带教距离**：导师 TRL 领先企业 IRL 1-2 级最佳，0-3 可接受  
- **15个交叉点类型**：每个类型对应特定的TRL-IRL组合，实现精准匹配
- **核心理念**：不是"找相同"，而是"诊断→处方→配药"  

### 2.2 15个交叉点类型

| 编号 | TRL-IRL组合 | 差距 | 类型名称 | 核心特征 |
|------|-------------|------|----------|----------|
| ① | T2-IRL1 | 1 | 概念引导型 | 导师有应用研究能力，企业刚识别需求 |
| ② | T3-IRL1 | 2 | 方案设计型 | 导师能做概念验证，企业刚识别需求 |
| ③ | T3-IRL2 | 1 | 原型开发型 | 导师能做概念验证，企业已有方案 |
| ④ | T4-IRL2 | 2 | 系统集成型 | 导师能做实验室验证，企业已有方案 |
| ⑤ | T4-IRL3 | 1 | 可行性验证型 | 导师能做实验室验证，企业已验证可行性 |
| ⑥ | T5-IRL3 | 2 | 工艺优化型 | 导师能做中试验证，企业已验证可行性 |
| ⑦ | T5-IRL4 | 1 | 标准制定型 | 导师能做中试验证，企业已定义技术细节 |
| ⑧ | T6-IRL4 | 2 | 量产准备型 | 导师能做小批量，企业已定义技术细节 |
| ⑨ | T6-IRL5 | 1 | 模拟验证型 | 导师能做小批量，企业已在相关环境验证 |
| ⑩ | T7-IRL5 | 2 | 真实环境型 | 导师能做批量生产，企业已在相关环境验证 |
| ⑪ | T7-IRL6 | 1 | 规模推广型 | 导师能做批量生产，企业已在真实环境验证 |
| ⑫ | T8-IRL6 | 2 | 运营优化型 | 导师能做规模化，企业已在真实环境验证 |
| ⑬ | T8-IRL7 | 1 | 深度集成型 | 导师能做规模化，企业已完整集成 |
| ⑭ | T9-IRL7 | 2 | 生态构建型 | 导师能做产业化，企业已完整集成 |
| ⑮ | T9-IRL8 | 1 | 持续创新型 | 导师能做产业化，企业已验证可靠 |

### 2.3 六维度匹配模型（权重设计）

| 维度 | 权重 | 说明 |
|---|---:|---|
| **行业匹配度** | **30%** | 行业标签、子行业、产业链位置匹配（第一位） |
| **技能对齐度** | **20%** | 导师技能与企业需求主题、CDIO能力、行业关键词匹配（第二位） |
| **TRL/IRL 适配度** | **20%** | 与需求等级、最佳带教距离直接相关（第三位） |
| 规模适配度 | 10% | 企业规模与导师服务方式、组织复杂度匹配 |
| 服务形式 | 10% | 陪跑/咨询/培训/方案评审等服务形式匹配 |
| 地域时间 | 10% | 城市、通勤、响应周期、项目时长匹配 |

**验证**：前三维度权重 = 30% + 20% + 20% = 70% > 66.67% ✅

### 2.4 匹配计算算法设计（含伪代码）

#### 2.4.1 总公式

```python
def calculate_final_score(mentor, enterprise, requirement):
    """
    计算最终匹配得分
    """
    # 1. 识别匹配类型
    match_type = identify_match_type(mentor.trl.level, enterprise.irl.level)
    
    # 2. 六维度评分
    industry_score = score_industry(mentor, enterprise)  # 30%
    skill_score = score_skill(mentor, enterprise, requirement)  # 20%
    trl_irl_score = score_trl_irl(mentor, enterprise, requirement)  # 20%
    scale_score = score_scale(mentor, enterprise)  # 10%
    service_score = score_service(mentor, enterprise, requirement)  # 10%
    geo_time_score = score_geo_time(mentor, enterprise)  # 10%
    
    # 3. 加权计算
    final_score = (
        0.30 * industry_score +
        0.20 * skill_score +
        0.20 * trl_irl_score +
        0.10 * scale_score +
        0.10 * service_score +
        0.10 * geo_time_score
    )
    
    return {
        'final_score': final_score,
        'match_type': match_type,
        'breakdown': {
            'industry': industry_score,
            'skill': skill_score,
            'trl_irl': trl_irl_score,
            'scale': scale_score,
            'service': service_score,
            'geo_time': geo_time_score
        }
    }
```

#### 2.4.2 识别匹配类型算法

```python
def identify_match_type(mentor_trl, enterprise_irl):
    """
    识别15个交叉点类型
    """
    gap = mentor_trl - enterprise_irl
    
    # 定义15个类型的映射
    type_mapping = {
        (2, 1): {"code": "①", "name": "概念引导型", "description": "导师有应用研究能力，企业刚识别需求"},
        (3, 1): {"code": "②", "name": "方案设计型", "description": "导师能做概念验证，企业刚识别需求"},
        (3, 2): {"code": "③", "name": "原型开发型", "description": "导师能做概念验证，企业已有方案"},
        (4, 2): {"code": "④", "name": "系统集成型", "description": "导师能做实验室验证，企业已有方案"},
        (4, 3): {"code": "⑤", "name": "可行性验证型", "description": "导师能做实验室验证，企业已验证可行性"},
        (5, 3): {"code": "⑥", "name": "工艺优化型", "description": "导师能做中试验证，企业已验证可行性"},
        (5, 4): {"code": "⑦", "name": "标准制定型", "description": "导师能做中试验证，企业已定义技术细节"},
        (6, 4): {"code": "⑧", "name": "量产准备型", "description": "导师能做小批量，企业已定义技术细节"},
        (6, 5): {"code": "⑨", "name": "模拟验证型", "description": "导师能做小批量，企业已在相关环境验证"},
        (7, 5): {"code": "⑩", "name": "真实环境型", "description": "导师能做批量生产，企业已在相关环境验证"},
        (7, 6): {"code": "⑪", "name": "规模推广型", "description": "导师能做批量生产，企业已在真实环境验证"},
        (8, 6): {"code": "⑫", "name": "运营优化型", "description": "导师能做规模化，企业已在真实环境验证"},
        (8, 7): {"code": "⑬", "name": "深度集成型", "description": "导师能做规模化，企业已完整集成"},
        (9, 7): {"code": "⑭", "name": "生态构建型", "description": "导师能做产业化，企业已完整集成"},
        (9, 8): {"code": "⑮", "name": "持续创新型", "description": "导师能做产业化，企业已验证可靠"},
    }
    
    # 查找匹配类型
    key = (mentor_trl, enterprise_irl)
    if key in type_mapping:
        return type_mapping[key]
    else:
        # 非最佳匹配区间
        if gap == 0:
            return {"code": "⚠️", "name": "同级互助型", "description": "导师与企业同级，可协作但缺乏引领"}
        elif gap == 3 or gap == 4:
            return {"code": "⚠️", "name": "差距较大型", "description": "差距较大，沟通成本高但仍有价值"}
        else:
            return {"code": "❌", "name": "不匹配", "description": "导师太落后或太超前"}
```

#### 2.4.3 行业匹配度评分算法

```python
def score_industry(mentor, enterprise):
    """
    行业匹配度评分（权重30%）
    """
    # 1. 精确匹配（同行业）
    exact_match = exact_tag_overlap(
        mentor.good_at_industries, 
        enterprise.industry_tags
    )
    
    # 2. 相关行业匹配（产业链上下游）
    related_match = related_industry_graph_score(
        mentor.good_at_industries, 
        enterprise.industry_tags
    )
    
    # 3. 行业经验深度
    industry_depth = mentor.industry_experience_years / 10
    
    # 4. 行业案例数量
    case_count_score = min(mentor.industry_cases_count / 10, 1.0)
    
    # 综合评分
    score = (
        0.4 * exact_match +           # 精确匹配 40%
        0.3 * related_match +         # 相关行业 30%
        0.2 * industry_depth +        # 行业深度 20%
        0.1 * case_count_score        # 案例数量 10%
    )
    
    return score
```

#### 2.4.4 技能对齐度评分算法

```python
def score_skill(mentor, enterprise, requirement):
    """
    技能对齐度评分（权重20%）
    """
    # 1. A1-A6技能匹配
    skill_overlap = overlap(
        mentor.skills,  # 导师技能标签
        requirement.skill_requirements  # 企业需求技能
    )
    
    # 2. 技能深度匹配
    depth_match = skill_depth_match(
        mentor.skill_depth,  # 导师技能深度
        requirement.skill_depth_required  # 企业需求深度
    )
    
    # 3. CDIO能力匹配（可选）
    cdio_match = cdio_overlap(
        mentor.cdio_roles,  # 导师CDIO角色
        requirement.expected_cdio_roles  # 企业期望CDIO角色
    )
    
    # 综合评分
    score = (
        0.5 * skill_overlap +         # 技能匹配 50%
        0.3 * depth_match +           # 深度匹配 30%
        0.2 * cdio_match              # CDIO匹配 20%
    )
    
    return score
```

#### 2.4.5 TRL/IRL成熟度适配评分算法

```python
def score_trl_irl(mentor, enterprise, requirement):
    """
    TRL/IRL成熟度适配评分（权重20%）
    """
    mentor_trl = mentor.trl.level
    enterprise_irl = enterprise.irl.level
    requirement_level = requirement.level  # L1/L2/L3/L4
    
    # 计算差距
    gap = mentor_trl - enterprise_irl
    
    # 根据需求等级确定最佳距离范围
    if requirement_level == "L1":  # 服务型
        ideal_min, ideal_max = 1, 2
    elif requirement_level == "L2":  # 工程型
        ideal_min, ideal_max = 1, 3
    elif requirement_level == "L3":  # 技术型
        ideal_min, ideal_max = 2, 4
    else:  # L4 研究型
        ideal_min, ideal_max = 3, 5
    
    # 计算距离得分
    if ideal_min <= gap <= ideal_max:
        # 最佳区间
        distance_score = 1.0
    elif 0 <= gap <= 5:
        # 可接受范围
        distance_score = 0.6 + 0.4 * (1 - abs(gap - (ideal_min + ideal_max) / 2) / 5)
    else:
        # 不匹配
        distance_score = 0.1
    
    # 置信度惩罚
    trl_confidence = mentor.trl.confidence
    irl_confidence = enterprise.irl.confidence
    confidence_penalty = min(trl_confidence, irl_confidence)
    
    # 最终得分
    score = distance_score * confidence_penalty
    
    return score
```

---

## 3. 数据采集方案

### 3.1 导师端数据采集

#### 3.1.1 必填字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 姓名 | 文本 | 导师姓名 |
| 职称 | 选择 | 教授/副教授/讲师/工程师等 |
| 所属机构 | 文本 | 学校/企业/研究机构 |
| 研究方向 | 多选 | 智能制造/机器视觉/工业机器人等 |
| 工作年限 | 数字 | 从业年限 |
| 服务形式 | 多选 | 咨询/方案评审/陪跑/培训等 |
| 联系方式 | 文本 | 微信/手机/邮箱 |

#### 3.1.2 TRL证据采集

| 证据类型 | 采集字段 | 验证方式 |
|----------|----------|----------|
| 学术证据 | 论文、专利、项目、奖项 | 知网/万方/基金委 |
| 技术证据 | 技术栈、项目经验、解决方案 | 项目证明/案例文档 |
| 工程证据 | 工作年限、管理经验、成功案例 | 企业证明/客户评价 |
| 产业证据 | 行业地位、资源网络、创业经历 | 工商信息/行业认可 |

### 3.2 企业端数据采集

#### 3.2.1 必填字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 企业名称 | 文本 | 公司全称 |
| 所属行业 | 选择 | 装备制造/汽车/3C电子等 |
| 企业规模 | 选择 | 小型/中型/大型/超大型 |
| 所在城市 | 文本 | 企业所在地 |
| 联系人 | 文本 | 主要联系人 |
| 联系方式 | 文本 | 手机/微信 |

#### 3.2.2 IRL评估问卷（18题）

**IT基础设施（5题）**
1. 贵公司目前的服务器部署方式是？
2. 贵公司的网络安全防护等级是？
3. 贵公司的IT运维方式是？
4. 贵公司的网络架构是？
5. 贵公司的数据存储方式是？

**数据基础（4题）**
6. 贵公司的数据治理成熟度是？
7. 贵公司的数据质量管理方式是？
8. 贵公司的数据安全合规情况是？
9. 贵公司的数据应用场景是？

**团队能力（4题）**
10. 贵公司的技术团队规模是？
11. 贵公司的管理团队专业度是？
12. 贵公司的培训体系完善度是？
13. 贵公司的创新能力是？

**管理流程（3题）**
14. 贵公司的项目管理方式是？
15. 贵公司的质量管理方式是？
16. 贵公司的流程规范程度是？

**预算资源（2题）**
17. 贵公司年度IT预算是？
18. 贵公司年度研发预算是？

---

## 4. 数据库设计

### 4.1 PostgreSQL 核心表

```sql
-- 导师表
CREATE TABLE mentors (
    id BIGINT PRIMARY KEY,
    name VARCHAR(100),
    trl_level INT,  -- TRL 等级 (1-9)
    skills JSON,    -- 技能标签
    industries JSON, -- 行业经验
    project_scale INT, -- 项目规模等级
    service_style VARCHAR(50), -- 服务形式
    location VARCHAR(100), -- 地域
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- 企业表
CREATE TABLE enterprises (
    id BIGINT PRIMARY KEY,
    name VARCHAR(200),
    irl_level INT,  -- IRL 等级 (1-9)
    industry VARCHAR(100), -- 所属行业
    scale INT, -- 企业规模
    needs JSON, -- 需求技能
    preference JSON, -- 偏好设置
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- 匹配记录表
CREATE TABLE match_records (
    id BIGINT PRIMARY KEY,
    mentor_id BIGINT,
    enterprise_id BIGINT,
    match_type_code VARCHAR(10), -- 匹配类型代码（①-⑮）
    match_type_name VARCHAR(50), -- 匹配类型名称
    match_score DECIMAL(5,4), -- 匹配分数 (0-1)
    industry_score DECIMAL(5,4), -- 行业匹配度
    skill_score DECIMAL(5,4), -- 技能对齐度
    trl_irl_score DECIMAL(5,4), -- TRL/IRL适配度
    scale_score DECIMAL(5,4), -- 规模适配度
    service_score DECIMAL(5,4), -- 服务形式适配
    geo_time_score DECIMAL(5,4), -- 地域时间适配
    recommendation_reason TEXT, -- 推荐理由
    status VARCHAR(20), -- 状态
    created_at TIMESTAMP,
    FOREIGN KEY (mentor_id) REFERENCES mentors(id),
    FOREIGN KEY (enterprise_id) REFERENCES enterprises(id)
);

-- 评估记录表
CREATE TABLE assessment_records (
    id BIGINT PRIMARY KEY,
    entity_type VARCHAR(20), -- mentor/enterprise
    entity_id BIGINT,
    assessment_type VARCHAR(50), -- trl/irl
    score INT, -- 评估分数
    evidence JSON, -- 评估证据
    assessor VARCHAR(100), -- 评估人
    created_at TIMESTAMP
);
```

### 4.2 Elasticsearch 搜索索引

```json
{
  "mappings": {
    "properties": {
      "mentor_id": {"type": "keyword"},
      "name": {"type": "text", "analyzer": "ik_max_word"},
      "trl_level": {"type": "integer"},
      "primary_domains": {"type": "keyword"},
      "good_at_industries": {"type": "keyword"},
      "available_service_modes": {"type": "keyword"},
      "location": {"type": "keyword"},
      "status": {"type": "keyword"}
    }
  }
}
```

---

## 5. API 接口设计

### 5.1 导师服务

```python
# 创建导师
POST /api/v1/mentors
{
    "name": "刘银华",
    "title": "硕士生导师",
    "org": "上海理工大学",
    "primary_domains": ["智能制造", "机器视觉"]
}

# 添加TRL证据
POST /api/v1/mentors/{mentor_id}/evidence
{
    "type": "academic",
    "data": {
        "degree": "博士",
        "publications_total": 25
    }
}

# 触发TRL评估
POST /api/v1/mentors/{mentor_id}/assess-trl
```

### 5.2 企业服务

```python
# 创建企业
POST /api/v1/enterprises
{
    "name": "上海XX智能装备有限公司",
    "industry": "装备制造",
    "scale": "100-300人"
}

# 提交IRL问卷
POST /api/v1/enterprises/{enterprise_id}/irl-questionnaire
{
    "answers": [1, 2, 3, 2, 1, 2, 3, 2, 1, 2, 3, 2, 1, 2, 3, 2, 1, 2]
}
```

### 5.3 匹配服务

```python
# 发起匹配
POST /api/v1/matches
{
    "requirement_id": "req_001",
    "enterprise_id": "ent_001",
    "max_candidates": 10
}

# 查询匹配结果
GET /api/v1/matches/{match_id}

# 获取匹配详情（含15类型信息）
GET /api/v1/matches/{match_id}/detail
```

---

## 6. 技术实现路径

### 6.1 技术栈推荐

| 组件 | 推荐方案 | 理由 |
|------|----------|------|
| 后端框架 | Python FastAPI | 快速开发，丰富的AI生态 |
| 数据库 | PostgreSQL | 关系型数据，支持JSON |
| 搜索引擎 | Elasticsearch | 全文检索，支持复杂查询 |
| 缓存 | Redis | 高性能缓存，支持分布式 |
| 任务队列 | Celery | 异步任务处理 |
| 前端 | React + Ant Design | 企业级UI组件库 |

### 6.2 部署架构

```
┌─────────────────────────────────────────────────────────────┐
│                    LinkedEvery 部署架构                       │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   导师端      │  │   企业端      │  │   运营端      │       │
│  │  (Web + H5)  │  │  (Web + H5)  │  │  (Web后台)   │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                  │                  │                │
│  ┌──────┴──────────────────┴──────────────────┴───────┐      │
│  │                   API Gateway                       │      │
│  └──────┬──────────────────┬──────────────────┬───────┘      │
│         │                  │                  │                │
│  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐      │
│  │ 导师画像服务  │  │ 企业诊断服务  │  │  匹配引擎    │      │
│  │ (TRL评估)    │  │ (IRL评估)    │  │ (15类型+6维度)│      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │                │
│  ┌──────┴──────────────────┴──────────────────┴───────┐      │
│  │               数据层 (PostgreSQL + Redis + ES)       │      │
│  └────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### 6.3 实施路线图

| 阶段 | 时间 | 目标 | 交付物 |
|------|------|------|--------|
| Phase 1 | 4周 | MVP匹配 | 基础数据模型 + 规则匹配 + 15类型展示 |
| Phase 2 | 4周 | 引擎完善 | 六维度评分 + 候选筛选 + 多样性优化 |
| Phase 3 | 4周 | 数据增强 | 证据链完善 + 冷启动优化 + 反馈闭环 |
| Phase 4 | 4周 | ML智能化 | 机器学习排序 + 个性化推荐 + 持续优化 |

---

## 7. 总结

### 7.1 核心设计原则

1. **15个交叉点类型**：实现更精准的匹配和定价
2. **六维度匹配模型**：前三维度权重占比70%
3. **证据与评分分离**：确保匹配结果可解释、可追溯
4. **先规则后ML**：先跑通规则引擎，再引入机器学习

### 7.2 技术亮点

1. **完整的15类型匹配算法**：每个类型有明确的导师特征、企业特征、匹配重点
2. **六维度加权评分**：行业30% + 技能20% + TRL/IRL20% + 规模10% + 服务10% + 地域10%
3. **可解释性优先**：每个匹配结果都有明确的匹配理由
4. **生产级技术架构**：K8s部署 + 主从数据库 + 缓存策略

---

**文档版本**：v2.0  
**最后更新**：2026-06-16  
**维护人**：小角（LinkedEvery 产品经理）
