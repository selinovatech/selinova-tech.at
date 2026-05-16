-- ============================================================
-- SELINOVATECH — Optimized Asset Marketplace (FIXED VERSION)
-- Run this on a CLEAN database (or after full DROP)
-- ============================================================

-- 1. Drop everything safely
DROP VIEW IF EXISTS v_asset_overview;
DROP TABLE IF EXISTS asset_views, list_items, lists, asset_tags, tags, asset_files, assets, categories, users CASCADE;

-- ============================================================
-- 2. Recreate tables (same as optimized version)
-- ============================================================

CREATE TABLE users (
    id            SERIAL PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(20)  NOT NULL DEFAULT 'buyer'
                      CHECK (role IN ('admin', 'buyer')),
    display_name  VARCHAR(100),
    avatar_url    TEXT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE categories (
    id          SERIAL PRIMARY KEY,
    parent_id   INT          REFERENCES categories(id) ON DELETE SET NULL,
    name        VARCHAR(100) NOT NULL,
    slug        VARCHAR(120) NOT NULL UNIQUE,
    description TEXT,
    sort_order  SMALLINT     NOT NULL DEFAULT 0
);

-- ============================================================
-- 3. SAFE CATEGORY SEED (NO explicit ID → avoids duplicate key error)
-- ============================================================
INSERT INTO categories (name, slug, sort_order) VALUES
    ('Digitale Dateien',     'digital-files',      1),
    ('Software & Lizenzen',  'software-licenses',  2),
    ('Medien',               'media',              3)
ON CONFLICT (slug) DO NOTHING;

-- Child categories (parent_id will be correct because we just inserted above)
INSERT INTO categories (parent_id, name, slug, sort_order) VALUES
    ((SELECT id FROM categories WHERE slug = 'digital-files'), '3D Modelle',    '3d-models',    1),
    ((SELECT id FROM categories WHERE slug = 'digital-files'), 'Templates',     'templates',    2),
    ((SELECT id FROM categories WHERE slug = 'digital-files'), 'Code',          'code',         3),
    ((SELECT id FROM categories WHERE slug = 'software-licenses'), 'Desktop Apps',  'desktop-apps', 1),
    ((SELECT id FROM categories WHERE slug = 'software-licenses'), 'Web Apps',     'web-apps',     2),
    ((SELECT id FROM categories WHERE slug = 'software-licenses'), 'Plugins',      'plugins',      3),
    ((SELECT id FROM categories WHERE slug = 'media'), 'Bilder',        'images',       1),
    ((SELECT id FROM categories WHERE slug = 'media'), 'Videos',        'videos',       2),
    ((SELECT id FROM categories WHERE slug = 'media'), 'Audio',         'audio',        3)
ON CONFLICT (slug) DO NOTHING;

-- ============================================================
-- 4. ASSETS table + trigger + indexes (same as before)
-- ============================================================
CREATE TABLE assets (
    id            SERIAL PRIMARY KEY,
    title         VARCHAR(255) NOT NULL,
    slug          VARCHAR(300) NOT NULL UNIQUE,
    short_desc    VARCHAR(200),
    description   TEXT,
    category_id   INT          NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    asset_type    VARCHAR(30)  NOT NULL CHECK (asset_type IN ('digital_file', 'software_license', 'image', 'video', 'audio')),
    license_type  VARCHAR(20)  NOT NULL DEFAULT 'standard' CHECK (license_type IN ('free', 'standard', 'extended', 'custom')),
    price         NUMERIC(10,2) DEFAULT 0.00,
    status        VARCHAR(20)  NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    created_by    INT          NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_assets_category   ON assets(category_id);
CREATE INDEX idx_assets_status     ON assets(status);
CREATE INDEX idx_assets_asset_type ON assets(asset_type);
CREATE INDEX idx_assets_price      ON assets(price);
CREATE INDEX idx_assets_fts ON assets USING GIN (
    to_tsvector('german', coalesce(title,'') || ' ' || coalesce(short_desc,'') || ' ' || coalesce(description,''))
);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trg_assets_updated_at
    BEFORE UPDATE ON assets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 5. Other tables (unchanged)
-- ============================================================
CREATE TABLE asset_files (
    id              SERIAL PRIMARY KEY,
    asset_id        INT          NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    file_role       VARCHAR(20)  NOT NULL CHECK (file_role IN ('thumbnail', 'preview', 'sample', 'main', 'download')),
    file_url        TEXT         NOT NULL,
    mime_type       VARCHAR(100),
    file_size_bytes BIGINT,
    sort_order      SMALLINT     NOT NULL DEFAULT 0
);

CREATE INDEX idx_asset_files_asset ON asset_files(asset_id);
CREATE INDEX idx_asset_files_role  ON asset_files(file_role);

CREATE TABLE tags (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(80)  NOT NULL UNIQUE,
    slug VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE asset_tags (
    asset_id INT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    tag_id   INT NOT NULL REFERENCES tags(id)   ON DELETE CASCADE,
    PRIMARY KEY (asset_id, tag_id)
);

CREATE TABLE lists (
    id         SERIAL PRIMARY KEY,
    user_id    INT          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name       VARCHAR(100) NOT NULL DEFAULT 'Merkliste',
    is_public  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE list_items (
    id       SERIAL PRIMARY KEY,
    list_id  INT NOT NULL REFERENCES lists(id)  ON DELETE CASCADE,
    asset_id INT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (list_id, asset_id)
);

CREATE TABLE asset_views (
    id         BIGSERIAL PRIMARY KEY,
    asset_id   INT         NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    user_id    INT         REFERENCES users(id) ON DELETE SET NULL,
    ip_address INET,
    viewed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_asset_views_asset ON asset_views(asset_id);
CREATE INDEX idx_asset_views_time  ON asset_views(viewed_at);

CREATE VIEW v_asset_overview AS
SELECT
    a.id,
    a.title,
    a.slug,
    a.short_desc,
    a.asset_type,
    a.license_type,
    a.price,
    a.status,
    c.name         AS category_name,
    cp.name        AS parent_category,
    COUNT(av.id)   AS total_views,
    a.created_at
FROM assets a
JOIN categories c   ON a.category_id = c.id
LEFT JOIN categories cp ON c.parent_id = cp.id
LEFT JOIN asset_views av ON av.asset_id = a.id
GROUP BY a.id, a.title, a.slug, a.short_desc, a.asset_type, a.license_type, a.price, a.status, c.name, cp.name, a.created_at;

-- ============================================================
-- 6. SAMPLE DATA (safe with ON CONFLICT)
-- ============================================================

-- Users
INSERT INTO users (email, password_hash, role, display_name, avatar_url) VALUES
    ('admin@selinovatech.com', '$2b$12$examplehashforadmin', 'admin', 'Selina Admin', '/avatars/admin.png'),
    ('buyer@example.com', '$2b$12$examplehashforbuyer', 'buyer', 'Max Mustermann', '/avatars/buyer.png')
ON CONFLICT (email) DO NOTHING;

-- Tags
INSERT INTO tags (name, slug) VALUES
    ('Responsive', 'responsive'),
    ('Figma', 'figma'),
    ('Landing Page', 'landing-page'),
    ('E-Commerce', 'e-commerce'),
    ('Anime', 'anime'),
    ('Fast Food', 'fast-food'),
    ('Blockchain', 'blockchain'),
    ('Metaverse', 'metaverse'),
    ('Nachhaltigkeit', 'sustainability'),
    ('Social Commerce', 'social-commerce'),
    ('Dashboard', 'dashboard'),
    ('UI Kit', 'ui-kit'),
    ('Video', 'video'),
    ('Blueprint', 'blueprint'),
    ('Premium', 'premium')
ON CONFLICT (slug) DO NOTHING;

-- ============================================================
-- 20 ASSETS (with correct category_id via subquery)
-- ============================================================

-- 101 Modern Landing Page → Templates (slug 'templates')
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Modern Landing Page', 'modern-landing-page', 'Responsives Landing-Page-Template mit Hero & CTA',
       'Vollständiges responsives Landing-Page-Template mit Hero-Bereich, CTA-Buttons und Kundenstimmen.',
       (SELECT id FROM categories WHERE slug = 'templates'), 'digital_file', 'free', 0.00, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 102 SaaS Dashboard → Web Apps
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'SaaS Dashboard', 'saas-dashboard', 'Modernes Dashboard mit Statistik-Karten & Darkmode',
       'Professionelles SaaS-Dashboard mit interaktiven Karten, Diagrammen und Darkmode.',
       (SELECT id FROM categories WHERE slug = 'web-apps'), 'digital_file', 'standard', 9.99, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 103 Portfolio Showcase → Templates
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Portfolio Showcase', 'portfolio-showcase', 'Schickes Portfolio-Template für Designer & Freelancer',
       'Elegantes Portfolio-Template mit Projektgalerie und animierten Übergängen.',
       (SELECT id FROM categories WHERE slug = 'templates'), 'digital_file', 'free', 0.00, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 104 Product Feature Block → Templates
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Product Feature Block', 'product-feature-block', 'Feature-Abschnitt mit Icon-Grid & Vergleichstabelle',
       'Modularer Feature-Block mit Icon-Grid und Launch-CTA.',
       (SELECT id FROM categories WHERE slug = 'templates'), 'digital_file', 'standard', 6.50, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 105 Pricing Table Kit → Templates
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Pricing Table Kit', 'pricing-table-kit', 'Responsives Pricing-Table für SaaS & Produkte',
       'Vollständiges Pricing-Table-Layout mit Highlight-Spalte und Toggle.',
       (SELECT id FROM categories WHERE slug = 'templates'), 'digital_file', 'standard', 4.99, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 201 Promo Video Pack → Videos
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Promo Video Pack', 'promo-video-pack', 'Hochwertige Promo-Vorlagen für Social Media',
       'Sammlung moderner Promo-Videos mit Intro und dynamischen Übergängen.',
       (SELECT id FROM categories WHERE slug = 'videos'), 'video', 'standard', 14.99, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 202 Webinar Intro → Videos
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Webinar Intro', 'webinar-intro', 'Animierte Intro-Sequenz für Webinare & Präsentationen',
       'Professionelle animierte Intro mit Countdown und Branding-Sektion.',
       (SELECT id FROM categories WHERE slug = 'videos'), 'video', 'standard', 12.00, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 203 Social Media Reel → Videos
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Social Media Reel', 'social-media-reel', 'Kurzvideo-Vorlage für Instagram Reels & TikTok',
       'Vertikales Short-Form-Video-Template mit Text-Overlays.',
       (SELECT id FROM categories WHERE slug = 'videos'), 'video', 'standard', 8.50, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 204 Animated Backgrounds → Videos
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Animated Backgrounds', 'animated-backgrounds', 'Loopfähige animierte Hintergründe',
       'Hochwertige animierte Hintergründe mit Farbvarianten und HD-Export.',
       (SELECT id FROM categories WHERE slug = 'videos'), 'video', 'free', 0.00, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 205 Demo Screen Recordings → Videos
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Demo Screen Recordings', 'demo-screen-recordings', 'Professionelle Bildschirmaufnahmen für Demos',
       'Hochwertige Screencasts mit Voiceover-Placeholder und Cursor-Animationen.',
       (SELECT id FROM categories WHERE slug = 'videos'), 'video', 'standard', 11.00, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 301–305 Blueprints → Code (or Templates – using Code for technical feel)
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'App Architecture Blueprint', 'app-architecture-blueprint', 'Strukturierte App-Architektur mit Komponenten-Map',
       'Vollständige App-Architektur-Blueprint mit Komponentenfluss und Deployment-Map.',
       (SELECT id FROM categories WHERE slug = 'code'), 'digital_file', 'standard', 7.50, 'published', 1
ON CONFLICT (slug) DO NOTHING;

INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'UX Flowchart Kit', 'ux-flowchart-kit', 'Visuelle UX-Workflows & User Journey Maps',
       'Professionelle UX-Flowcharts mit User Journey Map und Conversion-Pfaden.',
       (SELECT id FROM categories WHERE slug = 'code'), 'digital_file', 'standard', 5.99, 'published', 1
ON CONFLICT (slug) DO NOTHING;

INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'SaaS System Map', 'saas-system-map', 'Blueprint für SaaS-Systemkomponenten & APIs',
       'Umfassende SaaS-System-Map mit Service-Übersicht und API-Schnittstellen.',
       (SELECT id FROM categories WHERE slug = 'code'), 'digital_file', 'free', 0.00, 'published', 1
ON CONFLICT (slug) DO NOTHING;

INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Data Pipeline Blueprint', 'data-pipeline-blueprint', 'Datenfluss-Blueprint für ETL & Analytics',
       'Vollständiger Daten-Pipeline-Blueprint mit Quellen-Mapping und Batch/Echtzeit.',
       (SELECT id FROM categories WHERE slug = 'code'), 'digital_file', 'standard', 9.00, 'published', 1
ON CONFLICT (slug) DO NOTHING;

INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'API Design Blueprint', 'api-design-blueprint', 'REST-API-Blueprint mit Endpunkten & Auth',
       'Professioneller API-Blueprint mit REST-Endpoints und Authentifizierungsschema.',
       (SELECT id FROM categories WHERE slug = 'code'), 'digital_file', 'standard', 6.99, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- 401–405 UI Kits → Templates
INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Mobile UI Kit', 'mobile-ui-kit', 'UI-Komponenten für moderne mobile Apps',
       'Komplettes Mobile-UI-Kit mit Buttons, Formularen und responsivem Layout.',
       (SELECT id FROM categories WHERE slug = 'templates'), 'digital_file', 'standard', 13.50, 'published', 1
ON CONFLICT (slug) DO NOTHING;

INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Admin Panel Kit', 'admin-panel-kit', 'Vollständiges Admin-Dashboard mit Tabellen & KPIs',
       'Professionelles Admin-Panel mit Tabellen, Widgets und interaktiven Filtern.',
       (SELECT id FROM categories WHERE slug = 'web-apps'), 'digital_file', 'standard', 14.00, 'published', 1
ON CONFLICT (slug) DO NOTHING;

INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Ecommerce UI Kit', 'ecommerce-ui-kit', 'Vollständiges E-Commerce UI-Set für Shops',
       'Komplettes E-Commerce-UI-Kit mit Produktkarten, Warenkorb und Checkout-Flow.',
       (SELECT id FROM categories WHERE slug = 'templates'), 'digital_file', 'standard', 15.99, 'published', 1
ON CONFLICT (slug) DO NOTHING;

INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Form Component Set', 'form-component-set', 'Responsives Formular-Set mit Validierung',
       'Umfangreiche Sammlung responsiver Formularelemente inkl. Inputs und Error-States.',
       (SELECT id FROM categories WHERE slug = 'templates'), 'digital_file', 'free', 0.00, 'published', 1
ON CONFLICT (slug) DO NOTHING;

INSERT INTO assets (title, slug, short_desc, description, category_id, asset_type, license_type, price, status, created_by)
SELECT 'Dashboard Widget Kit', 'dashboard-widget-kit', 'KPI-Widgets & Diagramm-Module für Dashboards',
       'Modulare Widget-Sammlung für KPI-Übersichten und Team-Reports.',
       (SELECT id FROM categories WHERE slug = 'web-apps'), 'digital_file', 'standard', 8.50, 'published', 1
ON CONFLICT (slug) DO NOTHING;

-- ============================================================
-- 7. Asset Files (using your preview images)
-- ============================================================
-- Note: Run these AFTER the assets above so asset_id exists

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/Landingpage.png', 'image/png', 1 FROM assets WHERE slug = 'modern-landing-page'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/kalender.png', 'image/png', 1 FROM assets WHERE slug = 'saas-dashboard'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/RetroCyber.png', 'image/png', 1 FROM assets WHERE slug = 'portfolio-showcase'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/landingpage4.png', 'image/png', 1 FROM assets WHERE slug = 'product-feature-block'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/landingpage4.6.png', 'image/png', 1 FROM assets WHERE slug = 'pricing-table-kit'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/landingpage4.3.png', 'image/png', 1 FROM assets WHERE slug = 'promo-video-pack'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/landingpage4.4.png', 'image/png', 1 FROM assets WHERE slug = 'webinar-intro'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/webshop50.2.png', 'image/png', 1 FROM assets WHERE slug = 'social-media-reel'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/300web-bilder-werbung.png', 'image/png', 1 FROM assets WHERE slug = 'animated-backgrounds'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/^kalender.png', 'image/png', 1 FROM assets WHERE slug = 'demo-screen-recordings'
ON CONFLICT DO NOTHING;

-- Add more preview files for the rest (same pattern)
INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/webshop50.3.png', 'image/png', 1 FROM assets WHERE slug = 'app-architecture-blueprint'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/Webshop Pro + Livechat Ai.png', 'image/png', 1 FROM assets WHERE slug = 'ux-flowchart-kit'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/webshop50.png', 'image/png', 1 FROM assets WHERE slug = 'saas-system-map'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/webshop50.5.png', 'image/png', 1 FROM assets WHERE slug = 'data-pipeline-blueprint'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/Fast Food Webshopapp.png', 'image/png', 1 FROM assets WHERE slug = 'api-design-blueprint'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/webshop50.1.png', 'image/png', 1 FROM assets WHERE slug = 'mobile-ui-kit'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/Webshop Pro + Livechat Ai2.png', 'image/png', 1 FROM assets WHERE slug = 'admin-panel-kit'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/webshop50.4.png', 'image/png', 1 FROM assets WHERE slug = 'ecommerce-ui-kit'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/webshop50.6.png', 'image/png', 1 FROM assets WHERE slug = 'form-component-set'
ON CONFLICT DO NOTHING;

INSERT INTO asset_files (asset_id, file_role, file_url, mime_type, sort_order)
SELECT id, 'preview', '/previews/landingpage4.5.png', 'image/png', 1 FROM assets WHERE slug = 'dashboard-widget-kit'
ON CONFLICT DO NOTHING;

-- ============================================================
-- Done! Run this script completely.
-- ============================================================