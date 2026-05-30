-- ============================================================
-- MENTORSHIP SYSTEM - FINAL SCHEMA (Option 1: App-enforced subtypes)
-- PostgreSQL
-- ============================================================
-- Notes:
-- 1) Subtype consistency (person.identity_role <-> student/alumni rows) is enforced by backend logic:
--    - Insert into person, then insert into student OR alumni within one transaction.
-- 2) No triggers are used in this schema.
-- 3) Indexes are added for common search/matching queries.

-- ============================================================
-- 0. (Optional) Extensions
-- ============================================================
-- If you want case-insensitive email later, you can enable citext and change person.email type to citext.
-- CREATE EXTENSION IF NOT EXISTS citext;

-- ============================================================
-- 1. COUNTRY
-- ============================================================
CREATE TABLE country (
  code CHAR(2) PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE
);

-- ============================================================
-- 2. STUDY_LEVEL
-- ============================================================
CREATE TABLE study_level (
  id SERIAL PRIMARY KEY,
  name VARCHAR(30) NOT NULL UNIQUE
);



-- ============================================================
-- 3. FACULTY
-- ============================================================
CREATE TABLE faculty (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE
);



ALTER TABLE faculty
ADD COLUMN code CHAR(2) UNIQUE;






-- ============================================================
-- 4. INSTITUTE
-- ============================================================
CREATE TABLE institute (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  faculty_id INT NOT NULL,
  FOREIGN KEY (faculty_id) REFERENCES faculty(id)
);


ALTER TABLE institute
ADD COLUMN code CHAR(4) UNIQUE;

-- ============================================================
-- 5. DEPARTMENT
-- ============================================================
-- CREATE TABLE department (
--   id SERIAL PRIMARY KEY,
--   name VARCHAR(255) NOT NULL UNIQUE,
--   institute_id INT NOT NULL,
--   FOREIGN KEY (institute_id) REFERENCES institute(id)
-- );

-- drop table department;

-- ============================================================
-- 6. PROGRAMME
-- ============================================================
CREATE TABLE programme (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL
);




ALTER TABLE programme
ADD COLUMN institute_id INT;


ALTER TABLE programme add FOREIGN KEY (institute_id) REFERENCES institute(id);

ALTER TABLE programme
ADD COLUMN faculty_id INT not null;


ALTER TABLE programme add FOREIGN KEY (faculty_id) REFERENCES faculty(id);


ALTER TABLE programme
ADD COLUMN study_level_id INT not null;


ALTER TABLE programme add FOREIGN KEY (study_level_id) REFERENCES study_level(id);


-- ============================================================
-- 7. TOPIC (Reference)
-- ============================================================
CREATE TABLE topic (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  description TEXT
);

-- ============================================================
-- 8. PERSON (Supertype)
-- ============================================================
CREATE TABLE person (
  id SERIAL PRIMARY KEY,
  username VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,

  identity_role VARCHAR(50) NOT NULL
    CHECK (identity_role IN ('student', 'alumni')),

  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  address VARCHAR(255),

  email VARCHAR(255) NOT NULL UNIQUE,
  phone_number VARCHAR(50),

  home_country CHAR(2),
  FOREIGN KEY (home_country) REFERENCES country(code)
);

-- Helpful indexes for login/search
CREATE INDEX idx_person_identity_role ON person(identity_role);
CREATE INDEX idx_person_home_country ON person(home_country);



ALTER TABLE person ADD COLUMN profile_published BOOLEAN DEFAULT FALSE;
ALTER TABLE person ADD COLUMN preferences_published BOOLEAN DEFAULT FALSE;

-- ============================================================
-- 9. STUDENT (Subtype)
-- ============================================================
CREATE TABLE student (
  person_id INT PRIMARY KEY,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

-- ============================================================
-- 10. ALUMNI (Subtype)
-- ============================================================
CREATE TABLE alumni (
  person_id INT PRIMARY KEY,
  linkedin_profile VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

-- ============================================================
-- 11. EDUCATION
-- ============================================================
CREATE TABLE education (
  id SERIAL PRIMARY KEY,
  person_id INT NOT NULL,
  programme_id INT NOT NULL,
  study_level_id INT NOT NULL,
  start_date DATE,
  end_date DATE,

  FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE,
  FOREIGN KEY (programme_id) REFERENCES programme(id),
  FOREIGN KEY (study_level_id) REFERENCES study_level(id),

  CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE INDEX idx_education_person_id ON education(person_id);
CREATE INDEX idx_education_programme_id ON education(programme_id);
CREATE INDEX idx_education_study_level_id ON education(study_level_id);

-- ============================================================
-- 12. CAREER (Alumni only, enforced by FK to alumni)
-- ============================================================
CREATE TABLE career (
  id SERIAL PRIMARY KEY,
  person_id INT NOT NULL,
  job_title VARCHAR(100),
  company_name VARCHAR(255),
  start_date DATE,
  end_date DATE,
  job_description VARCHAR(255),
  country_code CHAR(2),

  FOREIGN KEY (person_id) REFERENCES alumni(person_id) ON DELETE CASCADE,
  FOREIGN KEY (country_code) REFERENCES country(code),

  CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE INDEX idx_career_person_id ON career(person_id);
CREATE INDEX idx_career_country_code ON career(country_code);

-- ============================================================
-- 13. PREFERENCE (PERSON ↔ TOPIC with one role per topic per person)
-- ============================================================
CREATE TABLE preference (
  person_id INT NOT NULL,
  topic_id INT NOT NULL,

  preference_role VARCHAR(50) NOT NULL
    CHECK (preference_role IN ('mentor', 'mentee', 'two_way')),

  PRIMARY KEY (person_id, topic_id),

  FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE,
  FOREIGN KEY (topic_id) REFERENCES topic(id)
);

-- Matching/search indexes
CREATE INDEX idx_preference_person_id ON preference(person_id);
CREATE INDEX idx_preference_topic_id ON preference(topic_id);
CREATE INDEX idx_preference_topic_role ON preference(topic_id, preference_role);

-- ============================================================
-- 14. MENTORSHIP (Student ↔ Alumni only)
-- ============================================================
CREATE TABLE mentorship (
  id SERIAL PRIMARY KEY,

  student_id INT NOT NULL,
  alumni_id INT NOT NULL,
  topic_id INT NOT NULL,

  mentorship_type VARCHAR(50) NOT NULL
    CHECK (mentorship_type IN ('traditional', 'reverse', 'two_way')),

  status VARCHAR(50) NOT NULL
    CHECK (status IN ('active', 'completed', 'cancelled')),

  start_date DATE NOT NULL,
  end_date DATE,

  FOREIGN KEY (student_id) REFERENCES student(person_id) ON DELETE CASCADE,
  FOREIGN KEY (alumni_id) REFERENCES alumni(person_id) ON DELETE CASCADE,
  FOREIGN KEY (topic_id) REFERENCES topic(id),

  UNIQUE (topic_id, student_id, alumni_id),

  CHECK (student_id <> alumni_id),
  CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE INDEX idx_mentorship_student_id ON mentorship(student_id);
CREATE INDEX idx_mentorship_alumni_id ON mentorship(alumni_id);
CREATE INDEX idx_mentorship_topic_id ON mentorship(topic_id);
CREATE INDEX idx_mentorship_status ON mentorship(status);
CREATE INDEX idx_mentorship_topic_status ON mentorship(topic_id, status);



ALTER TABLE mentorship
DROP COLUMN status;

ALTER TABLE mentorship
ADD COLUMN status VARCHAR(50) NOT NULL DEFAULT 'active'
CHECK (status IN ('active', 'completed', 'cancelled'));


-- ============================================================
-- END
-- ============================================================




CREATE TABLE mentorship_request (
    id SERIAL PRIMARY KEY,

    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    topic_id INT NOT NULL,
    mentorship_id INT,

    status VARCHAR(50) NOT NULL
      CHECK (status IN ('pending', 'accepted', 'rejected')),

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    pair_key VARCHAR GENERATED ALWAYS AS (
        topic_id::VARCHAR || '|' ||
        LEAST(sender_id, receiver_id)::VARCHAR || '|' ||
        GREATEST(sender_id, receiver_id)::VARCHAR
    ) STORED,

    FOREIGN KEY (sender_id) REFERENCES person(id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES person(id) ON DELETE CASCADE,
    FOREIGN KEY (topic_id) REFERENCES topic(id),
    FOREIGN KEY (mentorship_id) REFERENCES mentorship(id) ON DELETE SET NULL,

    UNIQUE (pair_key),
    CHECK (sender_id <> receiver_id)
);

CREATE INDEX idx_mrequest_sender_id ON mentorship_request(sender_id);
CREATE INDEX idx_mrequest_receiver_id ON mentorship_request(receiver_id);
CREATE INDEX idx_mrequest_topic_id ON mentorship_request(topic_id);
CREATE INDEX idx_mrequest_status ON mentorship_request(status);
CREATE INDEX idx_mrequest_mentorship_id ON mentorship_request(mentorship_id);





-- ============================================================
-- MIGRATION: Mentorship Management additions
-- Run these once against your existing database
-- ============================================================


-- 1. Add end_reason column to mentorship table
--    (stores optional reason when a user completes or cancels)

ALTER TABLE mentorship
ADD COLUMN IF NOT EXISTS end_reason TEXT;


-- 2. Create mentorship_message table
--    (simple thread of messages per mentorship pair)

CREATE TABLE IF NOT EXISTS mentorship_message (
  id              SERIAL PRIMARY KEY,
  mentorship_id   INT NOT NULL,
  sender_id       INT NOT NULL,
  body            TEXT NOT NULL,
  sent_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (mentorship_id) REFERENCES mentorship(id) ON DELETE CASCADE,
  FOREIGN KEY (sender_id)     REFERENCES person(id)     ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_mmessage_mentorship_id ON mentorship_message(mentorship_id);
CREATE INDEX IF NOT EXISTS idx_mmessage_sender_id     ON mentorship_message(sender_id);
CREATE INDEX IF NOT EXISTS idx_mmessage_sent_at       ON mentorship_message(sent_at);

-- ============================================================
-- DONE
-- ============================================================


ALTER TABLE mentorship_message
ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_mmessage_is_read ON mentorship_message(is_read);






INSERT INTO faculty (name) VALUES
('Faculty of Arts and Humanities'),
('Faculty of Social Sciences'),
('Faculty of Medicine'),
('Faculty of Science and Technology');









UPDATE faculty
SET code = 'HV'
WHERE name = 'Faculty of Arts and Humanities';

UPDATE faculty
SET code = 'SV'
WHERE name = 'Faculty of Social Sciences';

UPDATE faculty
SET code = 'MV'
WHERE name = 'Faculty of Medicine';

UPDATE faculty
SET code = 'LT'
WHERE name = 'Faculty of Science and Technology';





INSERT INTO study_level (name) VALUES
('Bachelor'),
('Master'),
('PhD');





-- ============================================================
-- COUNTRY TABLE
-- ============================================================
INSERT INTO country (code, name) VALUES
('AF','Afghanistan'),
('AL','Albania'),
('DZ','Algeria'),
('AD','Andorra'),
('AO','Angola'),
('AG','Antigua and Barbuda'),
('AR','Argentina'),
('AM','Armenia'),
('AU','Australia'),
('AT','Austria'),
('AZ','Azerbaijan'),
('BS','Bahamas'),
('BH','Bahrain'),
('BD','Bangladesh'),
('BB','Barbados'),
('BY','Belarus'),
('BE','Belgium'),
('BZ','Belize'),
('BJ','Benin'),
('BT','Bhutan'),
('BO','Bolivia'),
('BA','Bosnia and Herzegovina'),
('BW','Botswana'),
('BR','Brazil'),
('BN','Brunei'),
('BG','Bulgaria'),
('BF','Burkina Faso'),
('BI','Burundi'),
('KH','Cambodia'),
('CM','Cameroon'),
('CA','Canada'),
('CV','Cape Verde'),
('CF','Central African Republic'),
('TD','Chad'),
('CL','Chile'),
('CN','China'),
('CO','Colombia'),
('KM','Comoros'),
('CG','Congo'),
('CR','Costa Rica'),
('HR','Croatia'),
('CU','Cuba'),
('CY','Cyprus'),
('CZ','Czech Republic'),
('DK','Denmark'),
('DJ','Djibouti'),
('DM','Dominica'),
('DO','Dominican Republic'),
('EC','Ecuador'),
('EG','Egypt'),
('SV','El Salvador'),
('GQ','Equatorial Guinea'),
('ER','Eritrea'),
('EE','Estonia'),
('ET','Ethiopia'),
('FJ','Fiji'),
('FI','Finland'),
('FR','France'),
('GA','Gabon'),
('GM','Gambia'),
('GE','Georgia'),
('DE','Germany'),
('GH','Ghana'),
('GR','Greece'),
('GD','Grenada'),
('GT','Guatemala'),
('GN','Guinea'),
('GW','Guinea-Bissau'),
('GY','Guyana'),
('HT','Haiti'),
('HN','Honduras'),
('HU','Hungary'),
('IS','Iceland'),
('IN','India'),
('ID','Indonesia'),
('IR','Iran'),
('IQ','Iraq'),
('IE','Ireland'),
('IL','Israel'),
('IT','Italy'),
('JM','Jamaica'),
('JP','Japan'),
('JO','Jordan'),
('KZ','Kazakhstan'),
('KE','Kenya'),
('KI','Kiribati'),
('KP','North Korea'),
('KR','South Korea'),
('KW','Kuwait'),
('KG','Kyrgyzstan'),
('LA','Laos'),
('LV','Latvia'),
('LB','Lebanon'),
('LS','Lesotho'),
('LR','Liberia'),
('LY','Libya'),
('LI','Liechtenstein'),
('LT','Lithuania'),
('LU','Luxembourg'),
('MG','Madagascar'),
('MW','Malawi'),
('MY','Malaysia'),
('MV','Maldives'),
('ML','Mali'),
('MT','Malta'),
('MH','Marshall Islands'),
('MR','Mauritania'),
('MU','Mauritius'),
('MX','Mexico'),
('FM','Micronesia'),
('MD','Moldova'),
('MC','Monaco'),
('MN','Mongolia'),
('ME','Montenegro'),
('MA','Morocco'),
('MZ','Mozambique'),
('MM','Myanmar'),
('NA','Namibia'),
('NR','Nauru'),
('NP','Nepal'),
('NL','Netherlands'),
('NZ','New Zealand'),
('NI','Nicaragua'),
('NE','Niger'),
('NG','Nigeria'),
('MK','North Macedonia'),
('NO','Norway'),
('OM','Oman'),
('PK','Pakistan'),
('PW','Palau'),
('PA','Panama'),
('PG','Papua New Guinea'),
('PY','Paraguay'),
('PE','Peru'),
('PH','Philippines'),
('PL','Poland'),
('PT','Portugal'),
('QA','Qatar'),
('RO','Romania'),
('RU','Russia'),
('RW','Rwanda'),
('KN','Saint Kitts and Nevis'),
('LC','Saint Lucia'),
('VC','Saint Vincent and the Grenadines'),
('WS','Samoa'),
('SM','San Marino'),
('ST','Sao Tome and Principe'),
('SA','Saudi Arabia'),
('SN','Senegal'),
('RS','Serbia'),
('SC','Seychelles'),
('SL','Sierra Leone'),
('SG','Singapore'),
('SK','Slovakia'),
('SI','Slovenia'),
('SB','Solomon Islands'),
('SO','Somalia'),
('ZA','South Africa'),
('ES','Spain'),
('LK','Sri Lanka'),
('SD','Sudan'),
('SR','Suriname'),
('SE','Sweden'),
('CH','Switzerland'),
('SY','Syria'),
('TW','Taiwan'),
('TJ','Tajikistan'),
('TZ','Tanzania'),
('TH','Thailand'),
('TL','Timor-Leste'),
('TG','Togo'),
('TO','Tonga'),
('TT','Trinidad and Tobago'),
('TN','Tunisia'),
('TR','Turkey'),
('TM','Turkmenistan'),
('TV','Tuvalu'),
('UG','Uganda'),
('UA','Ukraine'),
('AE','United Arab Emirates'),
('GB','United Kingdom'),
('US','United States'),
('UY','Uruguay'),
('UZ','Uzbekistan'),
('VU','Vanuatu'),
('VA','Vatican City'),
('VE','Venezuela'),
('VN','Vietnam'),
('YE','Yemen'),
('ZM','Zambia'),
('ZW','Zimbabwe'),
('XK', 'Kosovo');








-- ============================================================
-- TOPIC TABLE - Comprehensive Topics for Mentorship
-- ============================================================

INSERT INTO topic (name, description) VALUES

-- PROGRAMMING LANGUAGES
('Python', 'Python programming and development'),
('Java', 'Java programming and applications'),
('JavaScript', 'JavaScript and frontend development'),
('C++', 'C++ programming and systems development'),
('C#', 'C# and .NET development'),
('PHP', 'PHP web development'),
('Ruby', 'Ruby programming and Rails'),
('Go', 'Go programming language'),
('Rust', 'Rust programming language'),
('Swift', 'Swift programming for iOS'),
('Kotlin', 'Kotlin programming'),
('R', 'R programming for data science'),
('MATLAB', 'MATLAB programming and numerical computing'),
('SQL', 'SQL and database queries'),
('HTML/CSS', 'HTML and CSS for web design'),
('TypeScript', 'TypeScript programming'),

-- AI & MACHINE LEARNING
('Artificial Intelligence', 'AI, machine learning, and deep learning'),
('Machine Learning', 'Machine learning algorithms and applications'),
('Deep Learning', 'Deep learning and neural networks'),
('Natural Language Processing', 'NLP and text analysis'),
('Computer Vision', 'Computer vision and image processing'),
('Data Science', 'Data analysis and big data'),
('Neural Networks', 'Neural networks and deep learning'),
('TensorFlow', 'TensorFlow and Keras frameworks'),
('PyTorch', 'PyTorch framework'),
('Reinforcement Learning', 'Reinforcement learning and game AI'),
('Predictive Analytics', 'Predictive modeling and forecasting'),
('Big Data', 'Big data processing and Hadoop'),

-- WEB & MOBILE DEVELOPMENT
('Web Development', 'Web design and development'),
('Frontend Development', 'Frontend technologies and frameworks'),
('Backend Development', 'Backend development and APIs'),
('Full Stack Development', 'Full stack web development'),
('React', 'React.js framework'),
('Angular', 'Angular framework'),
('Vue.js', 'Vue.js framework'),
('Node.js', 'Node.js backend development'),
('Django', 'Django web framework'),
('Flask', 'Flask web framework'),
('Mobile App Development', 'Mobile app development'),
('iOS Development', 'iOS app development'),
('Android Development', 'Android app development'),
('Flutter', 'Flutter cross-platform development'),
('REST API', 'REST API design and development'),
('GraphQL', 'GraphQL and modern APIs'),
('Responsive Design', 'Responsive and mobile-first design'),

-- TECHNOLOGY & INFRASTRUCTURE
('Cloud Computing', 'Cloud services and infrastructure'),
('AWS', 'Amazon Web Services'),
('Google Cloud', 'Google Cloud Platform'),
('Azure', 'Microsoft Azure cloud'),
('Docker', 'Docker containerization'),
('Kubernetes', 'Kubernetes orchestration'),
('DevOps', 'DevOps practices and tools'),
('CI/CD', 'Continuous integration and deployment'),
('Git', 'Git version control'),
('Linux', 'Linux operating systems'),
('Windows Server', 'Windows server administration'),
('Database Design', 'Database management and design'),
('MongoDB', 'MongoDB and NoSQL databases'),
('PostgreSQL', 'PostgreSQL databases'),
('MySQL', 'MySQL databases'),
('Network Administration', 'Network management and administration'),
('Cybersecurity', 'Cybersecurity and information security'),
('Web Security', 'Web application security'),
('Ethical Hacking', 'Penetration testing and security'),
('Blockchain', 'Blockchain and cryptocurrency'),

-- DATA & ANALYTICS
('Data Analysis', 'Data analysis and visualization'),
('Tableau', 'Tableau data visualization'),
('Power BI', 'Power BI analytics'),
('Excel', 'Advanced Excel and data analysis'),
('Pandas', 'Pandas data manipulation'),
('NumPy', 'NumPy scientific computing'),
('Scikit-learn', 'Scikit-learn machine learning'),
('Statistical Analysis', 'Statistics and hypothesis testing'),
('Business Analytics', 'Business intelligence and analytics'),

-- DESIGN & UX/UI
('Graphic Design', 'Graphic design and visual design'),
('UI Design', 'User interface design'),
('UX Design', 'User experience design'),
('Web Design', 'Web design principles'),
('Figma', 'Figma design tool'),
('Adobe Creative Suite', 'Adobe Photoshop, Illustrator, XD'),
('Wireframing', 'Wireframing and prototyping'),
('User Research', 'User research and testing'),

-- FACULTY OF ARTS AND HUMANITIES
('History', 'Ancient, medieval, or modern history studies'),
('Archaeology', 'Archaeological research and fieldwork'),
('Estonian Language', 'Estonian linguistics and language studies'),
('General Linguistics', 'Linguistics theory and applications'),
('Philosophy', 'Philosophy, logic, and epistemology'),
('Semiotics', 'Semiotics and sign theory'),
('Cultural Research', 'Cultural studies and research'),
('Theology', 'Theology and religious studies'),
('Foreign Languages', 'Foreign language learning and teaching'),
('Literature', 'Literary studies and analysis'),

-- FACULTY OF SOCIAL SCIENCES
('Education', 'Educational theory, pedagogy, and teaching'),
('Political Studies', 'Political science and governance'),
('Economics', 'Economics and economic theory'),
('Business Administration', 'Business management and administration'),
('Psychology', 'Psychology and mental health'),
('Law', 'Legal studies and jurisprudence'),
('Social Studies', 'Sociology and social science'),
('Human Rights', 'Human rights and international law'),
('Public Policy', 'Public policy and governance'),

-- FACULTY OF MEDICINE
('Biomedicine', 'Biomedical research and translational medicine'),
('Pharmacy', 'Pharmacy and pharmaceutical sciences'),
('Dentistry', 'Dental medicine and oral health'),
('Clinical Medicine', 'Clinical medicine and patient care'),
('Family Medicine', 'Family medicine and primary care'),
('Public Health', 'Public health and epidemiology'),
('Nursing', 'Nursing and healthcare'),
('Sports Science', 'Sports science and physiology'),
('Physiotherapy', 'Physiotherapy and rehabilitation'),
('Medical Research', 'Biomedical research methodology'),

-- FACULTY OF SCIENCE AND TECHNOLOGY
('Computer Science', 'Computer science theory and fundamentals'),
('Physics', 'Physics and theoretical physics'),
('Chemistry', 'Chemistry and chemical engineering'),
('Mathematics', 'Mathematics and mathematical theory'),
('Marine Science', 'Marine biology and oceanography'),
('Molecular Biology', 'Molecular biology and cell biology'),
('Genetics', 'Genetics and genomics'),
('Ecology', 'Ecology and environmental science'),
('Astronomy', 'Astronomy and astrophysics'),
('Engineering', 'Engineering and technology'),
('Bioengineering', 'Bioengineering and biotechnology'),

-- BUSINESS & ENTREPRENEURSHIP
('Entrepreneurship', 'Starting and managing businesses'),
('Innovation', 'Innovation management and development'),
('Finance', 'Finance, investment, and accounting'),
('Marketing', 'Marketing strategy and digital marketing'),
('Digital Marketing', 'Digital marketing and social media'),
('SEO', 'Search engine optimization'),
('Content Marketing', 'Content creation and marketing'),
('Project Management', 'Project management and leadership'),
('Business Strategy', 'Strategic planning and business development'),
('Supply Chain', 'Supply chain management and logistics'),
('Consulting', 'Business consulting and advisory'),

-- LANGUAGE & COMMUNICATION
('English Language', 'English language teaching and learning'),
('French Language', 'French language learning'),
('German Language', 'German language learning'),
('Russian Language', 'Russian language learning'),
('Spanish Language', 'Spanish language learning'),
('Chinese Language', 'Chinese language learning'),
('Japanese Language', 'Japanese language learning'),
('Communication', 'Communication skills and public speaking'),
('Writing', 'Academic and creative writing'),
('Translation', 'Translation and interpretation'),
('Technical Writing', 'Technical documentation and writing'),
('Copywriting', 'Copywriting and content writing'),

-- PERSONAL DEVELOPMENT & SOFT SKILLS
('Leadership', 'Leadership skills and management'),
('Communication Skills', 'Professional communication'),
('Time Management', 'Time management and productivity'),
('Critical Thinking', 'Critical thinking and problem-solving'),
('Presentation Skills', 'Presentation and public speaking'),
('Teamwork', 'Team collaboration and cooperation'),
('Negotiation', 'Negotiation skills'),
('Conflict Resolution', 'Conflict resolution and mediation'),
('Emotional Intelligence', 'Emotional intelligence and self-awareness'),
('Creativity', 'Creative thinking and innovation'),
('Decision Making', 'Decision-making processes'),
('Mentoring', 'Mentoring and coaching others'),

-- RESEARCH & ACADEMIC
('Research Methods', 'Academic research methodology'),
('Academic Writing', 'Academic paper writing and publication'),
('Literature Review', 'Conducting literature reviews'),
('Thesis Writing', 'Thesis and dissertation writing'),
('Qualitative Research', 'Qualitative research methods'),
('Quantitative Research', 'Quantitative research methods'),
('Scientific Research', 'Scientific research and experimentation'),

-- CREATIVE & ARTS
('Music', 'Music theory and performance'),
('Visual Arts', 'Visual arts and design'),
('Creative Writing', 'Creative writing and storytelling'),
('Photography', 'Photography and visual media'),
('Video Production', 'Video editing and production'),
('Animation', 'Animation and motion graphics'),
('Storytelling', 'Storytelling and narrative'),

-- HEALTH & WELLNESS
('Fitness & Sports', 'Physical fitness and sports training'),
('Marathon Training', 'Marathon running and training'),
('Nutrition', 'Nutrition and healthy eating'),
('Mental Health', 'Mental health and wellbeing'),
('Yoga', 'Yoga and mindfulness'),
('Meditation', 'Meditation and stress management'),
('Wellness Coaching', 'Health coaching and wellness'),

-- ADDITIONAL SPECIALTIES
('Patent Law', 'Intellectual property and patents'),
('Environmental Law', 'Environmental law and sustainability'),
('International Relations', 'International relations and diplomacy'),
('Ethics', 'Ethics and moral philosophy'),
('Cultural Anthropology', 'Anthropology and cultural studies'),
('Gender Studies', 'Gender studies and LGBTQ+ studies'),
('Media Studies', 'Media, journalism, and communication'),
('Urban Planning', 'Urban planning and design'),
('Architecture', 'Architecture and building design'),
('Environmental Studies', 'Environmental science and sustainability'),
('Climate Change', 'Climate change and environmental issues'),
('Renewable Energy', 'Renewable energy and sustainability'),
('Biotechnology', 'Biotechnology and genetic engineering'),
('Pharmaceutical Development', 'Drug development and clinical trials'),
('Museum Studies', 'Museum curation and cultural heritage'),
('Entrepreneurial Mindset', 'Developing entrepreneurial skills'),
('Career Development', 'Career planning and professional growth'),
('Academic Coaching', 'Academic support and tutoring'),
('Social Media', 'Social media marketing and strategy'),
('E-commerce', 'E-commerce and online business'),
('Agile Methodology', 'Agile and Scrum development'),
('Software Testing', 'QA and software testing'),
('Game Development', 'Video game development'),
('Virtual Reality', 'VR and augmented reality'),
('IoT', 'Internet of Things and embedded systems'),
('Robotics', 'Robotics and automation'),
('3D Modeling', ' 3D design and CAD'),
('Microservices', 'Microservices architecture'),
('System Design', 'System architecture and design'),
('Software Architecture', 'Software design patterns');





COPY institute(name, faculty_id, code)
FROM 'C:/Thesis/draft_code/institute_sql_ready.csv'
DELIMITER ','
CSV HEADER;






COPY programme(name, study_level_id, faculty_id, institute_id)
FROM 'C:/Thesis/draft_code/programme_sql_ready.csv'
DELIMITER ',' CSV HEADER NULL 'NA';





DROP FUNCTION IF EXISTS get_matching_users(integer);



CREATE OR REPLACE FUNCTION get_matching_users(p_user_id INT)
RETURNS TABLE (
    from_user_id INT,
    to_user_id INT,
    to_user_first_name VARCHAR(255),
    to_user_last_name VARCHAR(255),
    to_user_home_country CHAR(2),
    to_user_identity_role VARCHAR(50),
    topics_with_roles JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p_user_id AS from_user_id,
        other_person.id AS to_user_id,
        other_person.first_name AS to_user_first_name,
        other_person.last_name AS to_user_last_name,
        other_person.home_country AS to_user_home_country,
        other_person.identity_role AS to_user_identity_role,
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'topic', t.name,
                'preference_role', other_pref.preference_role
            ) ORDER BY t.name
        ) AS topics_with_roles
    FROM person cu
    JOIN preference current_pref ON current_pref.person_id = cu.id
    JOIN person other_person ON other_person.identity_role != cu.identity_role
    JOIN preference other_pref ON other_pref.person_id = other_person.id
    JOIN topic t ON t.id = other_pref.topic_id
    WHERE cu.id = p_user_id
        AND cu.profile_published = TRUE
        AND cu.preferences_published = TRUE
        AND other_person.profile_published = TRUE
        AND other_person.preferences_published = TRUE
        AND other_pref.topic_id = current_pref.topic_id
        AND (
            CASE 
                WHEN current_pref.preference_role = 'mentee' 
                    THEN other_pref.preference_role = 'mentor'
                WHEN current_pref.preference_role = 'mentor' 
                    THEN other_pref.preference_role = 'mentee'
                WHEN current_pref.preference_role = 'two_way' 
                    THEN other_pref.preference_role = 'two_way'
            END
        )
        AND NOT EXISTS (
            SELECT 1 FROM request
            WHERE (from_person_id = p_user_id AND to_person_id = other_person.id)
               OR (from_person_id = other_person.id AND to_person_id = p_user_id)
            AND status NOT IN ('rejected', 'cancelled')
        )
    GROUP BY other_person.id, other_person.first_name, other_person.last_name, 
             other_person.home_country, other_person.identity_role
    ORDER BY other_person.first_name, other_person.last_name;
END;
$$ LANGUAGE plpgsql;


