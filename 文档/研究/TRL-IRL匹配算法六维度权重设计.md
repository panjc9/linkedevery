# TRL/IRL 匹配算法六维度权重设计

**更新日期**：2026-06-16  
**更新人**：海猪（产品负责人）  
**更新原因**：明确六维度权重排序，前三维度占比超过2/3

---

## 一、六维度匹配模型

### 1.1 核心公式

```
最终匹配得分 = 
    w1 × 行业匹配度 
  + w2 × 技能对齐度 
  + w3 × TRL/IRL成熟度适配 
  + w4 × 规模适配度 
  + w5 × 服务形式适配 
  + w6 × 地域时间适配

其中：
w1 > w2 > w3 > w4 > w5 > w6
w1 + w2 + w3 > 2/3（约66.67%）
```

### 1.2 权重分配方案

| 排序 | 维度 | 权重 | 说明 |
|------|------|------|------|
| **1** | **行业匹配度** | **30%** | 行业经验决定匹配质量 |
| **2** | **技能对齐度** | **20%** | A1-A6技能维度匹配 |
| **3** | **TRL/IRL成熟度适配** | **20%** | 技术成熟度差距 |
| **4** | 规模适配度 | 10% | 企业规模匹配 |
| **5** | 服务形式适配 | 10% | 服务形式匹配 |
| **6** | 地域时间适配 | 10% | 地域与时间匹配 |

**验证**：30% + 20% + 20% = 70% > 66.67% ✅

---

## 二、各维度详细说明

### 2.1 行业匹配度（权重30%）- 第一位

**定义**：导师行业经验与企业所属行业的匹配程度

**计算公式**：
```python
def score_industry(mentor, enterprise):
    """
    行业匹配度评分
    权重：30%
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

**设计理由**：
- 行业经验是匹配质量的基础
- 同行业导师能真正理解企业痛点
- 同行业成功案例更有参考价值
- 企业更信任有同行业经验的导师

---

### 2.2 技能对齐度（权重20%）- 第二位

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
    权重：20%
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

**设计理由**：
- A1-A6技能维度决定服务方向
- 技能匹配是服务内容的基础
- 企业需要特定技能的导师
- 技能对齐度直接影响服务质量

---

### 2.3 TRL/IRL成熟度适配（权重20%）- 第三位

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

**设计理由**：
- TRL/IRL差距决定指导效果
- 最佳带教距离是核心匹配原则
- 成熟度适配直接影响学习效果
- 企业需要能"够得着"的导师

---

### 2.4 规模适配度（权重10%）- 第四位

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

**设计理由**：
- 企业规模决定服务复杂度
- 导师需要有匹配规模的服务能力
- 规模不匹配可能导致服务效果不佳

---

### 2.5 服务形式适配（权重10%）- 第五位

**定义**：导师服务形式与企业偏好的匹配程度

**计算公式**：
```python
def score_service(mentor, enterprise, requirement):
    """
    服务形式适配评分
    权重：10%
    """
    # 服务形式匹配
    mode_overlap = overlap(
        mentor.available_service_modes,  # 导师可提供服务形式
        requirement.preferred_service_modes  # 企业期望服务形式
    )
    
    # 服务时长匹配
    duration_fit = duration_fit_score(
        mentor.preferred_engagement_length_months,  # 导师期望合作时长
        requirement.expected_duration_months  # 企业期望合作时长
    )
    
    # 综合评分
    score = 0.6 * mode_overlap + 0.4 * duration_fit
    
    return score
```

**服务形式类型**：
- 技术陪跑
- 咨询顾问
- 培训指导
- 方案评审
- 资源对接
- 专家会诊

**匹配规则**：
- 服务形式完全匹配：1.0分
- 服务形式部分匹配：0.6-0.8分
- 服务形式不匹配：0.2-0.4分

**设计理由**：
- 服务形式决定合作方式
- 企业有特定的服务偏好
- 服务形式匹配影响合作体验

---

### 2.6 地域时间适配（权重10%）- 第六位

**定义**：导师地域、时间与企业的匹配程度

**计算公式**：
```python
def score_geo_time(mentor, enterprise):
    """
    地域时间适配评分
    权重：10%
    """
    # 1. 地域匹配
    city_match = 1.0 if mentor.basic.city == enterprise.basic.city else 0.6
    
    # 2. 时间匹配
    urgency_fit = urgency_responsiveness(
        enterprise.requirement.urgency,  # 企业紧急程度
        mentor.matching_features.service_capacity_per_quarter  # 导师服务容量
    )
    
    # 3. 通勤成本（可选）
    commute_cost = commute_cost_score(
        mentor.basic.city,
        enterprise.basic.city
    )
    
    # 综合评分
    score = 0.4 * city_match + 0.3 * urgency_fit + 0.3 * (1 - commute_cost)
    
    return score
```

**匹配规则**：
- 同城市 + 时间充裕：1.0分
- 同城市 + 时间紧张：0.8分
- 不同城市 + 可远程：0.6分
- 不同城市 + 需现场：0.4分

**设计理由**：
- 地域影响服务便利性
- 时间匹配影响响应速度
- 通勤成本影响合作体验

---

## 三、最终匹配得分计算

### 3.1 总公式

```python
def calculate_final_score(mentor, enterprise, requirement):
    """
    计算最终匹配得分
    """
    # 六维度评分
    industry_score = score_industry(mentor, enterprise)  # 行业匹配度
    skill_score = score_skill(mentor, enterprise, requirement)  # 技能对齐度
    trl_irl_score = score_trl_irl(mentor, enterprise, requirement)  # TRL/IRL适配度
    scale_score = score_scale(mentor, enterprise)  # 规模适配度
    service_score = score_service(mentor, enterprise, requirement)  # 服务形式适配
    geo_time_score = score_geo_time(mentor, enterprise)  # 地域时间适配
    
    # 权重
    weights = {
        'industry': 0.30,
        'skill': 0.20,
        'trl_irl': 0.20,
        'scale': 0.10,
        'service': 0.10,
        'geo_time': 0.10
    }
    
    # 加权计算
    final_score = (
        weights['industry'] * industry_score +
        weights['skill'] * skill_score +
        weights['trl_irl'] * trl_irl_score +
        weights['scale'] * scale_score +
        weights['service'] * service_score +
        weights['geo_time'] * geo_time_score
    )
    
    # 返回结果
    return {
        'final_score': final_score,
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

### 3.2 权重验证

```
前三维度权重 = 30% + 20% + 20% = 70%
后三维度权重 = 10% + 10% + 10% = 30%
总权重 = 70% + 30% = 100%

前三维度占比 = 70% > 66.67% ✅
```

### 3.3 匹配等级划分

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
│                    六维度匹配流程                                 │
│                                                                   │
│  1. 需求解析                                                      │
│     ├─ 提取行业标签                                               │
│     ├─ 提取技能需求（A1-A6）                                      │
│     ├─ 提取TRL/IRL要求                                           │
│     ├─ 提取规模要求                                               │
│     ├─ 提取服务形式偏好                                           │
│     └─ 提取地域时间要求                                           │
│                                                                   │
│  2. 候选筛选                                                      │
│     ├─ 行业硬约束（必须同行业或相关行业）                         │
│     ├─ 技能硬约束（必须有相关技能）                               │
│     └─ TRL/IRL硬约束（差距不能过大）                              │
│                                                                   │
│  3. 六维度评分                                                    │
│     ├─ 行业匹配度（30%）← 第一位                                 │
│     ├─ 技能对齐度（20%）← 第二位                                 │
│     ├─ TRL/IRL适配度（20%）← 第三位                              │
│     ├─ 规模适配度（10%）                                          │
│     ├─ 服务形式适配（10%）                                        │
│     └─ 地域时间适配（10%）                                        │
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
匹配得分：0.82（良好）

六维度评分明细：
├─ 行业匹配度：0.95（30%权重）→ 0.2850
├─ 技能对齐度：0.88（20%权重）→ 0.1760
├─ TRL/IRL适配度：0.82（20%权重）→ 0.1640
├─ 规模适配度：0.78（10%权重）→ 0.0780
├─ 服务形式适配：0.85（10%权重）→ 0.0850
└─ 地域时间适配：0.90（10%权重）→ 0.0900

匹配理由：
1. 张教授深耕制造业20年，与贵司行业高度匹配（权重30%）
2. 张教授在A3（技术开发）维度有丰富经验，匹配贵司技术需求（权重20%）
3. 张教授TRL 7，贵司IRL 4，处于最佳带教距离（权重20%）
4. 张教授有中型企业服务经验，匹配贵司规模（权重10%）
5. 张教授可提供技术陪跑服务，匹配贵司期望（权重10%）
6. 张教授在上海，与贵司同城，响应及时（权重10%）
```

---

## 五、权重调整对比

### 5.1 权重排序确认

| 排序 | 维度 | 权重 | 说明 |
|------|------|------|------|
| **1** | **行业匹配度** | **30%** | 行业经验决定匹配质量 |
| **2** | **技能对齐度** | **20%** | A1-A6技能维度匹配 |
| **3** | **TRL/IRL成熟度适配** | **20%** | 技术成熟度差距 |
| **4** | 规模适配度 | 10% | 企业规模匹配 |
| **5** | 服务形式适配 | 10% | 服务形式匹配 |
| **6** | 地域时间适配 | 10% | 地域与时间匹配 |

### 5.2 前三维度权重验证

```
前三维度权重 = 30% + 20% + 20% = 70%
占比 = 70% / 100% = 70%
要求 = > 66.67%
验证 = 70% > 66.67% ✅
```

---

## 六、总结

### 6.1 核心设计原则

1. **行业优先**：行业匹配度权重最大（30%），行业经验是匹配质量的基础
2. **技能对齐**：A1-A6技能维度权重第二（20%），技能匹配决定服务方向
3. **成熟度适配**：TRL/IRL适配度权重第三（20%），成熟度差距决定指导效果
4. **辅助维度**：规模、服务形式、地域时间各占10%，提供补充匹配

### 6.2 匹配公式

```
最终匹配得分 = 
    30% × 行业匹配度 
  + 20% × 技能对齐度 
  + 20% × TRL/IRL成熟度适配 
  + 10% × 规模适配度 
  + 10% × 服务形式适配 
  + 10% × 地域时间适配
```

### 6.3 设计亮点

1. **前三维度主导**：行业+技能+TRL/IRL占比70%，确保核心匹配质量
2. **权重排序明确**：行业 > 技能 > TRL/IRL > 规模 > 服务 > 地域
3. **可解释性强**：每个维度都有明确的计算逻辑和匹配规则
4. **灵活可调**：辅助维度权重可根据业务需求微调

---

**文档版本**：v1.0  
**最后更新**：2026-06-16  
**维护人**：小角（LinkedEvery 产品经理）
