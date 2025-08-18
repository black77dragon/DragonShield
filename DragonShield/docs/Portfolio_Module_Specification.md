# Portfolio Module Concept: DragonShield

### 1.0 Introduction & Background

DragonShield is your robust application for managing and tracking investments. It currently focuses on individual instrument positions. The new **"Portfolio" module** aims to elevate this by introducing a layer of strategic thematic tracking and performance analysis. This module will allow you, as the portfolio manager and owner, to organize your investments around specific research-backed themes, track their evolution, and meticulously compare your actual holdings against both recommended and your own adjusted target allocations. Essentially, it creates a valuable strategic view on the investments you've made and stored within the DragonShield application.

---

### 2.0 Objectives

The primary objectives of the Portfolio module are:

* **Strategic Alignment:** Enable the grouping of individual instruments into higher-level investment themes derived from research.
* **Historical Tracking:** Provide a clear audit trail of how investment themes and their underlying instruments evolve over time, capturing both research updates and personal insights.
* **Performance Monitoring:** Facilitate the real-time comparison of actual portfolio allocations against defined target allocations (both research-driven and user-adjusted).
* **Informed Decision-Making:** Highlight deviations from target allocations to help you identify areas for rebalancing or re-evaluation.
* **Customization:** Offer flexibility for you to define and manage the lifecycle statuses of your investment themes.

---

### 3.0 Business Specification

This section details the functionalities from the perspective of the portfolio manager using the DragonShield application.

#### 3.1 Portfolio Theme Layer

At the top level, you will define a **"Portfolio Theme"** entity. Each theme represents a significant investment idea or a template for thematic allocation, typically sourced from a particular research provider (e.g., "Generative AI Growth," "Renewable Energy Transition").

* **Theme Definition:**
    * **Name:** A clear, concise name for the theme.
    * **Description:** A detailed text explanation of the investment theme, its rationale, and the originating research firm. This can be extensive.
    * **Attachments:** Ability to attach various files (e.g., PDF research reports, charts, images, presentations) to provide richer context and supporting documentation.
* **Status Management:**
    * Each Portfolio Theme can be assigned a **customizable status** (e.g., "To Be Updated," "In Review," "Finalized," "Archived").
    * Statuses will have a **color code** for quick visual reference on dashboards.
    * You can define and manage these statuses through a dedicated settings interface.

#### 3.2 Portfolio Update History

At the Portfolio Theme level, you will maintain a chronological **history of updates**. This tracks the evolution of the theme itself, including new strategic insights, market changes affecting the theme, or notes you add over time.

* Each update entry will include:
    * **Text Content:** A detailed description of the update.
    * **Attachments:** Relevant files (e.g., updated charts, supporting documents, revised outlooks) that relate to the theme-level change.
    * **Timestamp & User:** Automatic recording of when the update occurred and by which user (you, the portfolio manager).

#### 3.3 Instrument-Level Tracking

Within each Portfolio Theme, you will associate multiple **instruments (assets)** that you are actually holding or considering. For each instrument, you will store and track specific updates related to that asset within the context of the theme.

* **Asset Association:** Link existing instruments from your DragonShield holdings to a specific Portfolio Theme.
* **Research Updates:** Store regular updates related to this specific instrument from your research providers (e.g., new price targets, rating changes, revised fundamental analysis). These updates are typically long-form text.
* **Attachments:** Attach files (e.g., specific stock research reports, company updates) to these instrument-level updates.
* **Personal Notes:** A dedicated comment section where you can add your own notes, observations, or thoughts on the research provider's update or the instrument's performance within the theme.

#### 3.4 Deviation and Comparison Mechanism

This is a core analytical feature, allowing you to compare your actual holdings against two target allocation views.

* **Target Allocations:**
    * **Research Target Allocation:** The recommended allocation weight for a specific instrument within the theme, as provided by the research firm.
    * **User-Adjusted Target Allocation:** Your personal target allocation for that instrument.
        * Upon adding an instrument to a theme, this will **default** to the `Research Target Allocation`.
        * You can **manually adjust** this target if you deliberately decide not to invest in a certain stock, or wish to over/underweight it based on your own conviction, independent of the research recommendation.
* **Current Allocation:** This is dynamically calculated based on your real-time positions for that instrument within your DragonShield portfolio, relative to the total value of all instruments within that specific theme.
* **Dual Deviation Tracking:** The system will calculate and display two types of deviations:
    * **Deviation vs. Research:** The difference between your `Current Allocation` and the `Research Target Allocation`. This shows how closely you're following the original research recommendations.
    * **Deviation vs. User Target:** The difference between your `Current Allocation` and your `User-Adjusted Target Allocation`. This shows how well you're adhering to your *own* refined strategy for the theme.
* **Visualizations:** Clear graphical representations (e.g., bar charts, pie charts) will show these comparisons, making it easy to identify overweights/underweights.

#### 3.5 Status and Customization

* **User-Defined Statuses:** You can define and modify the status labels (e.g., "Draft," "Active," "Review Needed") and assign a unique color to each.
* **Lifecycle Management:** These statuses provide a flexible way to manage the lifecycle of each Portfolio Theme, from initial concept to active management and eventual archiving.

---

### 4.0 Technical Specification

This section outlines the underlying technical requirements and data structures necessary for implementing the Portfolio module.

#### 4.1 High-Level Architecture
*(Note: Diagrams for architecture would be included here. They should show the Portfolio module integrating with DragonShield's existing `Instruments` and `Positions` data stores.)*

#### 4.2 Data Model (Entity-Relationship Diagram)
*(Note: An ERD showing the relationships between the new tables would be included here.)*

**Detailed Schema:**

**4.2.1 `PortfolioTheme`**
* **`id`**: `UUID` (Primary Key)
* **`name`**: `VARCHAR(255)` (e.g., "AI & Robotics")
* **`description`**: `TEXT` (Detailed explanation of the theme)
* **`status_id`**: `UUID` (Foreign Key to `PortfolioThemeStatus`)
* **`created_at`**: `TIMESTAMP` (Timestamp of creation)
* **`updated_at`**: `TIMESTAMP` (Timestamp of last update)
* **`user_id`**: `UUID` (Foreign Key to `Users` table – for ownership)

**4.2.2 `PortfolioThemeStatus`**
* **`id`**: `UUID` (Primary Key)
* **`label`**: `VARCHAR(50)` (e.g., "To Be Updated", "Finalized")
* **`color_code`**: `VARCHAR(7)` (Hex color, e.g., `#00FF00`)
* **`user_id`**: `UUID` (Foreign Key to `Users` table – if statuses are user-specific, otherwise remove)

**4.2.3 `PortfolioThemeAsset`**
* **`id`**: `UUID` (Primary Key)
* **`portfolio_theme_id`**: `UUID` (Foreign Key to `PortfolioTheme`)
* **`instrument_id`**: `UUID` (Foreign Key to DragonShield's existing `Instruments` table)
* **`research_target_allocation_weight`**: `DECIMAL(5,4)` (e.g., 0.05 for 5%)
* **`user_adjusted_target_allocation_weight`**: `DECIMAL(5,4)` (Defaults to `research_target_allocation_weight`; can be manually adjusted by user)
* **`comment`**: `TEXT` (Optional notes on asset inclusion or adjustment reason)
* **`created_at`**: `TIMESTAMP`
* **`updated_at`**: `TIMESTAMP`

**4.2.4 `PortfolioThemeUpdate`**
* **`id`**: `UUID` (Primary Key)
* **`portfolio_theme_id`**: `UUID` (Foreign Key to `PortfolioTheme`)
* **`update_text`**: `TEXT` (Content of the update)
* **`created_at`**: `TIMESTAMP`
* **`user_id`**: `UUID` (Foreign Key to `Users` for attribution)

**4.2.5 `PortfolioThemeAssetUpdate`**
* **`id`**: `UUID` (Primary Key)
* **`portfolio_theme_asset_id`**: `UUID` (Foreign Key to `PortfolioThemeAsset`)
* **`research_provider_text`**: `TEXT` (Long-form text update from research)
* **`user_comment`**: `TEXT` (User's personal notes/observations)
* **`created_at`**: `TIMESTAMP`

**4.2.6 `FileAttachment`**
* **`id`**: `UUID` (Primary Key)
* **`resource_type`**: `VARCHAR(50)` (ENUM: 'portfolio_theme', 'portfolio_theme_update', 'portfolio_theme_asset_update')
* **`resource_id`**: `UUID` (Foreign Key to the specific parent record)
* **`file_name`**: `VARCHAR(255)`
* **`file_path`**: `TEXT` (Secure path to stored file in object storage)
* **`mime_type`**: `VARCHAR(50)` (e.g., 'application/pdf', 'image/jpeg')
* **`uploaded_at`**: `TIMESTAMP`

---

#### 4.3 API Endpoints

All endpoints use JSON over HTTPS and are prefixed with `/api/v1`. Breaking changes introduce `/api/v{n}`; prior major versions remain available for six months before deprecation.

**Standard Error Envelope**

```json
{
  "error": {
    "code": "STRING",
    "message": "Human readable description",
    "request_id": "UUID"
  }
}
```

**4.3.1 Portfolio Theme Management**

`POST /api/v1/portfolio-themes` — Create a new Portfolio Theme.
  * **201**
    ```json
    {"id":"uuid","name":"AI & Robotics"}
    ```
  * **400**
    ```json
    {"error":{"code":"VALIDATION_ERROR","message":"name required","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`GET /api/v1/portfolio-themes` — List Portfolio Themes.
  * **Query Parameters:** `page` (default 1), `per_page` (max 100), `status` (optional filter)
  * **200**
    ```json
    {"data":[{"id":"uuid","name":"AI & Robotics"}],"page":1,"per_page":50,"total":1}
    ```
  * **401**
    ```json
    {"error":{"code":"UNAUTHORIZED","message":"authentication required","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`GET /api/v1/portfolio-themes/{theme_id}` — Retrieve a Portfolio Theme.
  * **200**
    ```json
    {"id":"uuid","name":"AI & Robotics","description":"Theme description"}
    ```
  * **404**
    ```json
    {"error":{"code":"THEME_NOT_FOUND","message":"theme not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`PUT /api/v1/portfolio-themes/{theme_id}` — Update a Portfolio Theme.
  * **200**
    ```json
    {"id":"uuid","name":"AI & Robotics Updated"}
    ```
  * **404**
    ```json
    {"error":{"code":"THEME_NOT_FOUND","message":"theme not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`DELETE /api/v1/portfolio-themes/{theme_id}` — Delete a Portfolio Theme.
  * **204** – empty body
  * **404**
    ```json
    {"error":{"code":"THEME_NOT_FOUND","message":"theme not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

**4.3.2 Portfolio Theme Status Management**

`POST /api/v1/portfolio-theme-statuses` — Create a custom status.
  * **201**
    ```json
    {"id":"uuid","label":"To Be Updated","color_code":"#ff0000"}
    ```
  * **400**
    ```json
    {"error":{"code":"VALIDATION_ERROR","message":"label required","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`GET /api/v1/portfolio-theme-statuses` — List custom statuses.
  * **Query Parameters:** `page` (default 1), `per_page` (max 100)
  * **200**
    ```json
    {"data":[{"id":"uuid","label":"To Be Updated"}],"page":1,"per_page":50,"total":1}
    ```
  * **401**
    ```json
    {"error":{"code":"UNAUTHORIZED","message":"authentication required","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`PUT /api/v1/portfolio-theme-statuses/{status_id}` — Update a custom status.
  * **200**
    ```json
    {"id":"uuid","label":"Finalized"}
    ```
  * **404**
    ```json
    {"error":{"code":"STATUS_NOT_FOUND","message":"status not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`DELETE /api/v1/portfolio-theme-statuses/{status_id}` — Delete a custom status.
  * **204**
  * **404**
    ```json
    {"error":{"code":"STATUS_NOT_FOUND","message":"status not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

**4.3.3 Portfolio Theme Asset Management**

`POST /api/v1/portfolio-themes/{theme_id}/assets` — Add an instrument to a theme.
  * **201**
    ```json
    {"id":"uuid","instrument_id":"uuid","research_target_allocation_weight":0.05,"user_adjusted_target_allocation_weight":0.05}
    ```
  * **404**
    ```json
    {"error":{"code":"THEME_NOT_FOUND","message":"theme not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`PUT /api/v1/portfolio-themes/{theme_id}/assets/{asset_id}/target-allocation` — Adjust target allocation.
  * **200**
    ```json
    {"id":"uuid","user_adjusted_target_allocation_weight":0.07}
    ```
  * **404**
    ```json
    {"error":{"code":"ASSET_NOT_FOUND","message":"asset not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`DELETE /api/v1/portfolio-themes/{theme_id}/assets/{asset_id}` — Remove an instrument.
  * **204**
  * **404**
    ```json
    {"error":{"code":"ASSET_NOT_FOUND","message":"asset not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

**4.3.4 Update History Management**

`POST /api/v1/portfolio-themes/{theme_id}/updates` — Add a theme-level update.
  * **201**
    ```json
    {"id":"uuid","update_text":"Theme updated","created_at":"2024-01-01T00:00:00Z"}
    ```
  * **404**
    ```json
    {"error":{"code":"THEME_NOT_FOUND","message":"theme not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`GET /api/v1/portfolio-themes/{theme_id}/updates` — List theme updates.
  * **Query Parameters:** `page` (default 1), `per_page` (max 100), `since` (optional ISO8601 timestamp)
  * **200**
    ```json
    {"data":[{"id":"uuid","update_text":"Theme updated"}],"page":1,"per_page":50,"total":1}
    ```
  * **404**
    ```json
    {"error":{"code":"THEME_NOT_FOUND","message":"theme not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`POST /api/v1/portfolio-theme-assets/{asset_id}/updates` — Add an asset update.
  * **201**
    ```json
    {"id":"uuid","research_provider_text":"New price target","created_at":"2024-01-01T00:00:00Z"}
    ```
  * **404**
    ```json
    {"error":{"code":"ASSET_NOT_FOUND","message":"asset not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`GET /api/v1/portfolio-theme-assets/{asset_id}/updates` — List updates for an asset.
  * **Query Parameters:** `page` (default 1), `per_page` (max 100), `since` (optional ISO8601 timestamp)
  * **200**
    ```json
    {"data":[{"id":"uuid","research_provider_text":"New price target"}],"page":1,"per_page":50,"total":1}
    ```
  * **404**
    ```json
    {"error":{"code":"ASSET_NOT_FOUND","message":"asset not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

**4.3.5 Deviation and Comparison**

`GET /api/v1/portfolio-themes/{theme_id}/deviation` — Calculate and retrieve current allocations and deviations.
  * **200**
    ```json
    {
      "theme_id": "...",
      "theme_name": "...",
      "total_current_theme_value": 1000000.00,
      "asset_breakdown": [
        {
          "instrument_id": "uuid-123",
          "instrument_name": "Acme Corp",
          "current_value": 150000.00,
          "current_allocation_weight": 0.15,
          "research_target_allocation_weight": 0.20,
          "user_adjusted_target_allocation_weight": 0.18,
          "deviation_vs_research": -0.05,
          "deviation_vs_user_target": -0.03
        }
      ]
    }
    ```
  * **404**
    ```json
    {"error":{"code":"THEME_NOT_FOUND","message":"theme not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

**4.3.6 File Attachment Management**

`POST /api/v1/files/upload` — Upload a file and link it to a resource.
  * **201**
    ```json
    {"id":"uuid","file_name":"report.pdf","mime_type":"application/pdf"}
    ```
  * **400**
    ```json
    {"error":{"code":"VALIDATION_ERROR","message":"invalid file","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

`GET /api/v1/files/{file_id}` — Retrieve file metadata or serve the file.
  * **200**
    ```json
    {"id":"uuid","file_name":"report.pdf","mime_type":"application/pdf","download_url":"https://..."}
    ```
  * **404**
    ```json
    {"error":{"code":"FILE_NOT_FOUND","message":"file not found","request_id":"uuid"}}
    ```
  * **Version:** v1 (deprecated six months after v2 launch)

---

#### 4.4 Integration with Existing DragonShield Application

* **Authentication & Authorization:** The module must leverage DragonShield's existing user authentication and authorization system.
* **Database Integration:** The new tables will reside within the DragonShield database.
* **Data Lookup:** `instrument_id` in `PortfolioThemeAsset` will directly reference the existing `Instruments` table, and the deviation mechanism will query the `positions` table to get current holding values.
* **Performance:** Queries for deviation analysis must be optimized, possibly using database indexing and caching.
* **Error Handling:** Robust error handling should be implemented for all API endpoints.
