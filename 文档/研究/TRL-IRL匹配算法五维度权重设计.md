# TRL/IRL 匹配算法五维度权重设计

**更新日期**：2026-06-16  
**更新人**：海猪（产品负责人）  
**更新原因**：明确五维度权重排序

---

## 一、五维度匹配模型

### 1.1 核心公式

```
最终匹配得分 = 
    w1 × 行业匹配度 
  + w2 × 技能对齐度 
  + w3 × TRL/IRL成熟度适配 
  + w4 × 规模适配度 
  + w5 × 意愿匹配度

其中：
w1 > w2 > w3 > w4 > w5
```

### 1.2 权重分配方案

| 维度 | 权重 | 说明 | 计算方式 |
|------|------|------|----------|
| **行业匹配度** | **35%** | 行业经验决定匹配质量 | 导师行业经验 vs 企业所属行业 |
| **技能对齐度** | **25%** | A1-A6技能维度匹配 | 导师技能 vs 企业需求 |
| **TRL/IRL成熟度适配** | **20%** | 技术成熟度差距 | TRL - IRL 的适配程度 |
| **规模适配度** | **10%** | 企业规模与导师能力匹配 | 企业规模 vs 导师服务规模 |
| **意愿匹配度** | **10%** | 服务形式与合作意愿匹配 | 双方意愿的一致性 |

---

## 二、各维度详细说明

### 2.1 行业匹配度（权重35%）

**定义**：导师行业经验与企业所属行业的匹配程度

**计算公式**：
```python
def score_industry(mentor, enterprise):
    """
    行业匹配度评分
    权重：35%
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

**匹配规则**：
- 同行业：1.0分
- 相关行业：0.7-0.9分
- 跨行业：0.3-0.6分
- 完全不相关：0-0.2分

---

### 2.2 技能对齐度（权重25%）

**定义**：A1-A6技能维度的匹配程度

**A1-A6技能维度**：
| 维度 | 全称 | 能力描述 |
|------|------|----------|
| A1 | 战略规划 | 企业战略、业务规划、商业模式设计 |
| A2 | 运营管理 | 流程优化、组织管理、运营效率 |
| A3 | 技术开发 | 技术研发、产品开发、系统集成 |
| A4 | 市场营销 | 市场推广、品牌建设、客户获取 |
| A5 | 财务法务 | 财务管理、法务合规、投融资 |
| A6 | 人力资源 | 人才招聘、培训发展、绩效管理 |

**计算公式**：
```python
def score_skill(mentor, enterprise, requirement):
    """
    技能对齐度评分
    权重：25%
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

**匹配规则**：
- 完全匹配（同维度同深度）：1.0分
- 高度匹配（同维度不同深度）：0.8-0.9分
- 部分匹配（相关维度）：0.5-0.7分
- 低度匹配（不相关维度）：0.2-0.4分
- 不匹配：0-0.1分

---

### 2.3 TRL/IRL成熟度适配（权重20%）

**定义**：导师TRL与企业IRL的成熟度差距适配程度

**计算公式**：
```python
def score_trl_irl(mentor, enterprise, requirement):
    """
    TRL/IRL成熟度适配评分
    权重：20%
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

**匹配规则**：
- 最佳带教距离（TRL - IRL = 1~2）：1.0分
- 可用匹配（TRL - IRL = 0 或 3~4）：0.6-0.8分
- 不匹配（TRL - IRL < 0 或 > 4）：0.1-0.3分

---

### 2.4 规模适配度（权重10%）

**定义**：企业规模与导师服务能力的匹配程度

**计算公式**：
```python
def score_scale(mentor, enterprise):
    """
    规模适配度评分
    权重：10%
    """
    # 企业规模分类
    enterprise_scale = scale_bucket(enterprise.basic.scale)
    # 小型企业：1-50人
    # 中型企业：50-300人
    # 大型企业：300-1000人
    # 超大型企业：1000+人
    
    # 导师服务能力
    mentor_capacity = mentor.service_capacity_per_quarter
    
    # 匹配度计算
    if enterprise_scale == "小型":
        if mentor_capacity >= 5:
            fit = 1.0  # 导师有足够精力服务小型企业
        else:
            fit = 0.7
    elif enterprise_scale == "中型":
        if mentor_capacity >= 3:
            fit = 0.9
        else:
            fit = 0.6
    elif enterprise_scale == "大型":
        if mentor_capacity >= 2:
            fit = 0.8
        else:
            fit = 0.5
    else:  # 超大型
        if mentor_capacity >= 1:
            fit = 0.7
        else:
            fit = 0.4
    
    # 组织复杂度惩罚
    org_complexity = complexity_penalty(enterprise_scale, mentor.team_management_years)
    
    # 最终得分
    score = 0.7 * fit + 0.3 * (1 - org_complexity)
    
    return score
```

**匹配规则**：
- 小型企业 + 导师服务能力强：1.0分
- 中型企业 + 导师服务能力强：0.9分
- 大型企业 + 导师有大客户服务经验：0.8分
- 超大型企业 + 导师有集团服务经验：0.7分
- 规模不匹配：0.3-0.5分

---

### 2.5 意愿匹配度（权重10%）

**定义**：服务形式与合作意愿的匹配程度

**计算公式**：
```python
def score_willingness(mentor, enterprise, requirement):
    """
    意愿匹配度评分
    权重：10%
    """
    # 1. 服务形式匹配
    service_mode_overlap = overlap(
        mentor.available_service_modes,  # 导师可提供服务形式
        requirement.preferred_service_modes  # 企业期望服务形式
    )
    
    # 2. 合作意愿匹配
    mentor_willingness = mentor.willingness_score  # 导师合作意愿（1-10）
    enterprise_willingness = enterprise.willingness_score  # 企业合作意愿（1-10）
    
    willingness_match = min(mentor_willingness, enterprise_willingness) / 10
    
    # 3. 时间安排匹配
    time_fit = time_fit_score(
        mentor.availability,  # 导师可用时间
        requirement.urgency  # 企业紧急程度
    )
    
    # 综合评分
    score = (
        0.4 * service_mode_overlap +  # 服务形式匹配 40%
        0.3 * willingness_match +     # 合作意愿匹配 30%
        0.3 * time_fit                # 时间安排匹配 30%
    )
    
    return score
```

**匹配规则**：
- 服务形式完全匹配 + 双方意愿强：1.0分
- 服务形式部分匹配 + 意愿中等：0.6-0.8分
- 服务形式不匹配 + 意愿弱：0.2-0.4分

---

## 三、最终匹配得分计算

### 3.1 总公式

```python
def calculate_final_score(mentor, enterprise, requirement):
    """
    计算最终匹配得分
    """
    # 五维度评分
    industry_score = score_industry(mentor, enterprise)  # 行业匹配度
    skill_score = score_skill(mentor, enterprise, requirement)  # 技能对齐度
    trl_irl_score = score_trl_irl(mentor, enterprise, requirement)  # TRL/IRL适配度
    scale_score = score_scale(mentor, enterprise)  # 规模适配度
    willingness_score = score_willingness(mentor, enterprise, requirement)  # 意愿匹配度
    
    # 权重
    weights = {
        'industry': 0.35,
        'skill': 0.25,
        'trl_irl': 0.20,
        'scale': 0.10,
        'willingness': 0.10
    }
    
    # 加权计算
    final_score = (
        weights['industry'] * industry_score +
        weights['skill'] * skill_score +
        weights['trl_irl'] * trl_irl_score +
        weights['scale'] * scale_score +
        weights['willingness'] * willingness_score
    )
    
    # 返回结果
    return {
        'final_score': final_score,
        'breakdown': {
            'industry': industry_score,
            'skill': skill_score,
            'trl_irl': trl_irl_score,
            'scale': scale_score,
            'willingness': willingness_score
        }
    }
```

### 3.2 匹配等级划分

| 匹配等级 | 分数范围 | 说明 | 推荐策略 |
|----------|----------|------|----------|
| **优秀** | 0.85-1.0 | 强烈推荐 | 优先推荐，重点跟进 |
| **良好** | 0.70-0.84 | 推荐匹配 | 正常推荐 |
| **一般** | 0.50-0.69 | 可选匹配 | 备选推荐 |
| **较差** | 0.30-0.49 | 谨慎匹配 | 需人工审核 |
| **不匹配** | 0-0.29 | 不推荐 | 不推荐 |

---

## 四、匹配流程

### 4.1 完整匹配流程

```
┌─────────────────────────────────────────────────────────────────┐
│                    五维度匹配流程                                 │
│                                                                   │
│  1. 需求解析                                                      │
│     ├─ 提取行业标签                                               │
│     ├─ 提取技能需求（A1-A6）                                      │
│     ├─ 提取TRL/IRL要求                                           │
│     ├─ 提取规模要求                                               │
│     └─ 提取服务形式偏好                                           │
│                                                                   │
│  2. 候选筛选                                                      │
│     ├─ 行业硬约束（必须同行业或相关行业）                         │
│     ├─ 技能硬约束（必须有相关技能）                               │
│     └─ TRL/IRL硬约束（差距不能过大）                              │
│                                                                   │
│  3. 五维度评分                                                    │
│     ├─ 行业匹配度（35%）                                          │
│     ├─ 技能对齐度（25%）                                          │
│     ├─ TRL/IRL适配度（20%）                                       │
│     ├─ 规模适配度（10%）                                          │
│     └─ 意愿匹配度（10%）                                          │
│                                                                   │
│  4. 排序与推荐                                                    │
│     ├─ 按最终得分排序                                             │
│     ├─ Top 3 强烈推荐                                             │
│     ├─ Top 4-10 正常推荐                                          │
│     └─ 人工审核确认                                               │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 匹配结果展示

**示例匹配结果**：
```
推荐导师：张教授
匹配得分：0.87（优秀）

五维度评分明细：
├─ 行业匹配度：0.95（35%权重）→ 0.3325
├─ 技能对齐度：0.88（25%权重）→ 0.2200
├─ TRL/IRL适配度：0.82（20%权重）→ 0.1640
├─ 规模适配度：0.78（10%权重）→ 0.0780
└─ 意愿匹配度：0.90（10%权重）→ 0.0900

匹配理由：
1. 张教授深耕制造业20年，与贵司行业高度匹配
2. 张教授在A3（技术开发）维度有丰富经验，匹配贵司技术需求
3. 张教授TRL 7，贵司IRL 4，处于最佳带教距离
4. 张教授有中型企业服务经验，匹配贵司规模
5. 张教授可提供技术陪跑服务，匹配贵司期望
```

---

## 五、权重调整对比

### 5.1 从六维度到五维度

| 原六维度 | 新五维度 | 调整说明 |
|----------|----------|----------|
| 行业匹配度（15%） | **行业匹配度（35%）** | 权重提升+20% |
| TRL/IRL适配度（35%） | **TRL/IRL适配度（20%）** | 权重降低-15% |
| 技能对齐度（25%） | **技能对齐度（25%）** | 保持不变 |
| 规模适配度（10%） | **规模适配度（10%）** | 保持不变 |
| 服务形式（10%） | **意愿匹配度（10%）** | 合并服务形式和意愿 |
| 地域时间（5%） | 合并到意愿匹配度 | 合并到意愿匹配度 |

### 5.2 权重排序确认

| 排序 | 维度 | 权重 | 说明 |
|------|------|------|------|
| 1 | **行业匹配度** | **35%** | 行业经验决定匹配质量 |
| 2 | **技能对齐度** | **25%** | A1-A6技能维度匹配 |
| 3 | **TRL/IRL成熟度适配** | **20%** | 技术成熟度差距 |
| 4 | **规模适配度** | **10%** | 企业规模匹配 |
| 5 | **意愿匹配度** | **10%** | 服务形式与合作意愿 |

---

## 六、总结

### 6.1 核心变化

1. **维度简化**：从六维度简化为五维度
2. **权重调整**：行业匹配度从15%提升到35%，成为最大权重
3. **逻辑清晰**：权重排序明确，行业 > 技能 > TRL/IRL > 规模 > 意愿

### 6.2 匹配公式

```
最终匹配得分 = 
    35% × 行业匹配度 
  + 25% × 技能对齐度 
  + 20% × TRL/IRL成熟度适配 
  + 10% × 规模适配度 
  + 10% × 意愿匹配度
```

### 6.3 设计原则

1. **行业优先**：行业经验是匹配质量的基础
2. **技能对齐**：A1-A6技能维度决定服务方向
3. **成熟度适配**：TRL/IRL差距决定指导效果
4. **规模匹配**：企业规模决定服务复杂度
5. **意愿一致**：合作意愿决定项目成功率

---

**文档版本**：v1.0  
**最后更新**：2026-06-16  
**维护人**：小角（LinkedEvery 产品经理）
