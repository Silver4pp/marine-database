-- ============================================================
-- 02-data-dummy.sql — DATA DUMMY ERP PASIR LAUT (v3, 11 Sep 2026)
-- Dump dari kondisi UAT LENGKAP (120 asersi PASS): schema bisnis +
-- seed skenario UAT (klausul GPS 3/5 compliant, PNBP DUE relatif
-- CURRENT_DATE+1, geofence, IKAL, approval, RBAC, PDF-email,
-- PWA-survey-TTD).
-- Dipasang SETELAH 01-schema.sql (lihat kode/start.sh) — pemulihan
-- satu-langkah mereproduksi aplikasi demo penuh.
-- Catatan versi:
--   v1: hanya data inti tanpa skenario UAT → modul Klausul/PNBP
--       tampil kosong saat cold-start.
--   v2: + skenario UAT lengkap (112 asersi).
--   v3: schema commercial.bap kini menyertakan kolom TTD gambar
--       (signed_vessel_img/signed_customer_img/signed_surveyor_img,
--       NULL di seed — diisi via pad TTD di halaman BAP). Lih.
--       DATABASE-CHANGELOG.md.
-- ============================================================
--
-- PostgreSQL database dump
--

\restrict u6jhGoME6bbgrhfOGYcjXNuCignd0FyH6dcwgDFOgUMdAZauuTvR6yVnOdjPDbI

-- Dumped from database version 17.11 (Debian 17.11-0+deb13u1)
-- Dumped by pg_dump version 17.11 (Debian 17.11-0+deb13u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: info; Type: TABLE DATA; Schema: buyer; Owner: -
--

INSERT INTO buyer.info VALUES ('B-PRN', 'PT Pembangunan Reklamasi Nusantara', 'Ir. Rahmat', 'rahmat@prn.co.id', '2026-09-11 04:37:38.232279+00');
INSERT INTO buyer.info VALUES ('B-WKR', 'PT Wijaya Karya Reklamasi', 'Andi Prasetyo', 'andi@wkr.co.id', '2026-09-11 04:37:38.232279+00');
INSERT INTO buyer.info VALUES ('B-PSR', 'PT Pulau Sejahtara Reklamasi', 'Ir. Sinta Wijaya', 'sinta@psr.co.id', '2026-09-11 04:37:38.471111+00');
INSERT INTO buyer.info VALUES ('B-XPD', 'Pan Jurong Reclamation Pte Ltd', 'Lim Wei Sheng', 'ops@panjurong.sg', '2026-09-11 04:37:38.910326+00');


--
-- Data for Name: sand_spec; Type: TABLE DATA; Schema: commercial; Owner: -
--

INSERT INTO commercial.sand_spec VALUES (1, 'Spec Pasir Reklamasi G', '{"gradasi": "MEDIUM", "kadar_organik_pct": 3, "max_mud_content_pct": 5}', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: currency; Type: TABLE DATA; Schema: param; Owner: -
--

INSERT INTO param.currency VALUES ('IDR', 'Rupiah');
INSERT INTO param.currency VALUES ('USD', 'US Dollar');


--
-- Data for Name: info; Type: TABLE DATA; Schema: site; Owner: -
--

INSERT INTO site.info VALUES ('MARINA-JAYA', 'Marina Jaya', 'B-WKR', '0101000020E6100000CDCCCCCCCC8C5A403333333333B317C0', NULL);
INSERT INTO site.info VALUES ('SITE-G', 'Reklamasi G (Dumping Site)', 'B-PRN', '0101000020E6100000D7A3703D0A975A40E17A14AE47E117C0', '0103000020E61000000100000005000000AE47E17A14965A40D7A3703D0AD717C0D578E92631985A40A245B6F3FDD417C0B81E85EB51985A4021B0726891ED17C091ED7C3F35965A40560E2DB29DEF17C0AE47E17A14965A40D7A3703D0AD717C0');
INSERT INTO site.info VALUES ('ETAP-2', 'Reklamasi Etap 2', 'B-PRN', '0101000020E6100000E17A14AE47995A407B14AE47E1FA17C0', '0103000020E610000001000000050000009CC420B072985A40713D0AD7A3F017C00AD7A3703D9A5A403BDF4F8D97EE17C0EE7C3F355E9A5A40BA490C022B0718C07F6ABC7493985A40F0A7C64B370918C09CC420B072985A40713D0AD7A3F017C0');
INSERT INTO site.info VALUES ('SITE-JRG', 'Reclamation Area Jurong — Singapura', 'B-XPD', '0101000020E6100000AE47E17A14EE5940A4703D0AD7A3F43F', NULL);


--
-- Data for Name: sales_contract; Type: TABLE DATA; Schema: commercial; Owner: -
--

INSERT INTO commercial.sales_contract VALUES (1, 'SC-2026-014', 'B-PRN', 'SITE-G', '2026-01-10', '2026-12-31', 200000.000, 300000.000, 21500.0000, 'IDR', 1, 'DEPOSIT', 12, 4500000.00, 'AKTIF', true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO commercial.sales_contract VALUES (2, 'SC-2026-015', 'B-PSR', 'SITE-G', '2026-03-01', '2026-12-31', 50000.000, 150000.000, 21000.0000, 'IDR', 1, 'DEPOSIT', 12, 4000000.00, 'AKTIF', true, NULL, '2026-09-11 04:37:38.472003+00', '2026-09-11 04:37:38.472003+00');
INSERT INTO commercial.sales_contract VALUES (90, 'SC-2026-X01', 'B-XPD', 'SITE-JRG', '2026-08-10', '2027-08-09', 150000.000, 400000.000, 10.0000, 'USD', 1, 'PELUNASAN', 24, 0.00, 'AKTIF', true, NULL, '2026-09-11 04:37:38.921629+00', '2026-09-11 04:37:38.921629+00');


--
-- Data for Name: deposit; Type: TABLE DATA; Schema: buyer; Owner: -
--

INSERT INTO buyer.deposit VALUES (1, 1, 'IDR', 364506300.00, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO buyer.deposit VALUES (2, 2, 'IDR', 0.00, NULL, '2026-09-11 04:37:38.473406+00', '2026-09-11 04:37:38.473406+00');


--
-- Data for Name: ledger_hist; Type: TABLE DATA; Schema: buyer; Owner: -
--

INSERT INTO buyer.ledger_hist VALUES (1, 'B-PRN', '2026-01-12', 'DEPOSIT_TOPUP', 'TRF-2026-0117', 0.00, 700000000.00, 700000000.00);
INSERT INTO buyer.ledger_hist VALUES (2, 'B-PRN', '2026-09-02', 'BAP_DEDUCTION', 'BAP-2026-0085', 112875000.00, 0.00, 587125000.00);
INSERT INTO buyer.ledger_hist VALUES (3, 'B-PRN', '2026-09-04', 'BAP_DEDUCTION', 'BAP-2026-0086', 107124997.00, 0.00, 480000003.00);
INSERT INTO buyer.ledger_hist VALUES (4, 'B-PRN', '2026-09-04', 'ADJUSTMENT', 'KOREKSI-PEMBULATAN-0086', 3.00, 0.00, 480000000.00);
INSERT INTO buyer.ledger_hist VALUES (5, 'B-PRN', '2026-09-07', 'BAP_DEDUCTION', 'BAP-2026-0087', 115493700.00, 0.00, 364506300.00);
INSERT INTO buyer.ledger_hist VALUES (6, 'B-PSR', '2026-09-01', 'DEPOSIT_TOPUP', 'TRF-2026-0301', 0.00, 50000000.00, 50000000.00);
INSERT INTO buyer.ledger_hist VALUES (7, 'B-PSR', '2026-09-10', 'BAP_DEDUCTION', 'BAP-2026-0088', 50000000.00, 0.00, 0.00);


--
-- Data for Name: purchase_order; Type: TABLE DATA; Schema: commercial; Owner: -
--

INSERT INTO commercial.purchase_order VALUES (85, 'PO-2026-0085', 'B-PRN', 'SC-2026-014', 5250.000, 5250.000, '2026-08-28', 'COMPLETED', 1);
INSERT INTO commercial.purchase_order VALUES (86, 'PO-2026-0086', 'B-PRN', 'SC-2026-014', 5001.120, 4982.558, '2026-09-01', 'COMPLETED', 1);
INSERT INTO commercial.purchase_order VALUES (88, 'PO-2026-0088', 'B-PRN', 'SC-2026-014', 5420.500, 5371.800, '2026-09-04', 'COMPLETED', 1);
INSERT INTO commercial.purchase_order VALUES (91, 'PO-2026-0091', 'B-PSR', 'SC-2026-015', 3500.000, 0.000, '2026-09-08', 'CANCELLED', 2);
INSERT INTO commercial.purchase_order VALUES (90, 'PO-2026-0090', 'B-PSR', 'SC-2026-015', 4000.000, 3900.000, '2026-09-07', 'COMPLETED', 2);


--
-- Data for Name: info; Type: TABLE DATA; Schema: fleet; Owner: -
--

INSERT INTO fleet.info VALUES ('SL07', 'MV Sinar Laut 07', 'TSHD', 'AKTIF', NULL, NULL, NULL, 5400.000);
INSERT INTO fleet.info VALUES ('SL09', 'MV Sinar Laut 09', 'TSHD', 'AKTIF', NULL, NULL, NULL, 5400.000);
INSERT INTO fleet.info VALUES ('LI02', 'TB Laut Indah 02', 'TB', 'AKTIF', NULL, NULL, NULL, 2800.000);
INSERT INTO fleet.info VALUES ('M03', 'TB Mulya 03', 'TB', 'AKTIF', NULL, NULL, NULL, 5400.000);
INSERT INTO fleet.info VALUES ('B07', 'TB Bahari 07', 'TB', 'AKTIF', NULL, NULL, NULL, 4900.000);
INSERT INTO fleet.info VALUES ('SL02', 'MV Sinar Laut 02', 'TSHD', 'AKTIF', -5.97, 106.36, '2026-09-07 07:30:00+00', 5400.000);
INSERT INTO fleet.info VALUES ('SL05', 'MV Sinar Laut 05', 'TSHD', 'AKTIF', -5.73, 106.16, '2026-09-07 07:30:00+00', 5400.000);
INSERT INTO fleet.info VALUES ('B12', 'TB Bahari 12', 'TB', 'AKTIF', -5.925, 106.2, '2026-09-07 07:30:00+00', 4900.000);


--
-- Data for Name: delivery_order; Type: TABLE DATA; Schema: commercial; Owner: -
--

INSERT INTO commercial.delivery_order VALUES (330, 'DO-2026-0330', 86, 'MV Sinar Laut 09', 5001.120, '2026-09-03', 'CLOSED', 'SL09');
INSERT INTO commercial.delivery_order VALUES (341, 'DO-2026-0341', 88, 'MV Sinar Laut 02', 5420.500, '2026-09-05', 'CLOSED', 'SL02');
INSERT INTO commercial.delivery_order VALUES (329, 'DO-2026-0329', 85, 'MV Sinar Laut 05', 5250.000, '2026-09-01', 'CLOSED', 'SL05');
INSERT INTO commercial.delivery_order VALUES (353, 'DO-2026-0353', 91, 'MV Bahari 09', 3500.000, '2026-09-09', 'CANCELLED', 'SL09');
INSERT INTO commercial.delivery_order VALUES (352, 'DO-2026-0352', 90, 'MV Sinar Laut 05', 4000.000, '2026-09-08', 'CLOSED', 'SL05');


--
-- Data for Name: shipment_instruction; Type: TABLE DATA; Schema: operational; Owner: -
--

INSERT INTO operational.shipment_instruction VALUES (899, 'SI-2026-0899', 329, '2026-09-01 07:30:00+00', 'EXECUTED');
INSERT INTO operational.shipment_instruction VALUES (903, 'SI-2026-0903', 330, '2026-09-03 05:30:00+00', 'EXECUTED');
INSERT INTO operational.shipment_instruction VALUES (907, 'SI-2026-0907', 341, '2026-09-05 09:00:00+00', 'EXECUTED');
INSERT INTO operational.shipment_instruction VALUES (910, 'SI-2026-0910', 352, '2026-09-07 23:30:00+00', 'EXECUTED');
INSERT INTO operational.shipment_instruction VALUES (911, 'SI-2026-0911', 353, '2026-09-09 01:00:00+00', 'CANCELLED');
INSERT INTO operational.shipment_instruction VALUES (1, 'SI-2026-00851', NULL, '2026-07-16 15:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (2, 'SI-2026-00852', NULL, '2026-07-18 01:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (3, 'SI-2026-00853', NULL, '2026-07-19 05:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (4, 'SI-2026-00854', NULL, '2026-07-20 09:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (5, 'SI-2026-00855', NULL, '2026-07-21 13:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (6, 'SI-2026-00856', NULL, '2026-07-22 03:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (7, 'SI-2026-00857', NULL, '2026-07-22 17:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (8, 'SI-2026-00858', NULL, '2026-07-23 19:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (9, 'SI-2026-00859', NULL, '2026-07-24 23:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (10, 'SI-2026-00860', NULL, '2026-07-25 03:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (11, 'SI-2026-00861', NULL, '2026-07-26 07:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (12, 'SI-2026-00862', NULL, '2026-07-27 11:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (13, 'SI-2026-00863', NULL, '2026-07-27 11:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (14, 'SI-2026-00864', NULL, '2026-07-28 13:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (15, 'SI-2026-00865', NULL, '2026-07-29 17:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (16, 'SI-2026-00866', NULL, '2026-07-30 21:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (17, 'SI-2026-00867', NULL, '2026-07-31 01:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (18, 'SI-2026-00868', NULL, '2026-08-01 05:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (19, 'SI-2026-00869', NULL, '2026-08-02 07:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (20, 'SI-2026-00870', NULL, '2026-08-02 19:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (21, 'SI-2026-00871', NULL, '2026-08-03 11:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (22, 'SI-2026-00872', NULL, '2026-08-04 09:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (23, 'SI-2026-00873', NULL, '2026-08-04 15:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (24, 'SI-2026-00874', NULL, '2026-08-05 19:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (25, 'SI-2026-00875', NULL, '2026-08-06 23:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (26, 'SI-2026-00876', NULL, '2026-08-07 21:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (27, 'SI-2026-00877', NULL, '2026-08-08 05:00:00+00', 'ISSUED');
INSERT INTO operational.shipment_instruction VALUES (28, 'SI-2026-00878', NULL, '2026-08-10 17:00:00+00', 'ISSUED');


--
-- Data for Name: work_area; Type: TABLE DATA; Schema: operational; Owner: -
--

INSERT INTO operational.work_area VALUES ('B-04', 'Blok Pengerukan B-04', 'BLOK_KERUK', 'AKTIF', 'IPPL-2026-014-B04', 1200000.000, 876000.000);
INSERT INTO operational.work_area VALUES ('B-07', 'Blok Pengerukan B-07', 'BLOK_KERUK', 'AKTIF', 'IPPL-2026-014-B07', 800000.000, 259950.000);


--
-- Data for Name: trip; Type: TABLE DATA; Schema: operational; Owner: -
--

INSERT INTO operational.trip VALUES (899, 'TRP-2026-0899', 'SI-2026-0899', 'SL05', 'B-04', 'CLOSED', 'PUMP_ASHORE', '2026-08-31 18:00:00+00', '2026-09-01 08:00:00+00', '2026-09-01 14:00:00+00', '2026-09-01 14:30:00+00', '2026-09-01 20:00:00+00', '2026-09-01 22:10:00+00', '2026-09-03 02:00:00+00', 5250.000, 5250.000, 0.000, true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO operational.trip VALUES (903, 'TRP-2026-0903', 'SI-2026-0903', 'SL09', 'B-07', 'CLOSED', 'BOTTOM_DUMP', '2026-09-02 18:00:00+00', '2026-09-03 07:00:00+00', '2026-09-03 13:00:00+00', '2026-09-03 13:30:00+00', '2026-09-03 19:00:00+00', '2026-09-04 00:10:00+00', '2026-09-05 03:00:00+00', 5001.120, 4982.558, 18.562, true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO operational.trip VALUES (907, 'TRP-2026-0907', 'SI-2026-0907', 'SL02', 'B-04', 'SETTLED', 'PUMP_ASHORE', '2026-09-04 18:00:00+00', '2026-09-06 11:00:00+00', '2026-09-06 19:00:00+00', '2026-09-07 02:30:00+00', '2026-09-07 06:00:00+00', '2026-09-07 07:35:00+00', NULL, 5420.500, 5371.800, 26.400, true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO operational.trip VALUES (910, 'TRP-2026-0910', 'SI-2026-0910', 'SL05', 'B-07', 'INVOICED', 'PUMP_ASHORE', '2026-09-07 23:00:00+00', '2026-09-08 07:00:00+00', '2026-09-09 10:30:00+00', '2026-09-09 15:00:00+00', '2026-09-09 18:00:00+00', '2026-09-09 19:15:00+00', NULL, 4000.000, 3950.000, 20.000, false, NULL, '2026-09-11 04:37:38.478612+00', '2026-09-11 04:37:38.478612+00');
INSERT INTO operational.trip VALUES (911, 'TRP-2026-0911', 'SI-2026-0911', 'SL09', 'B-07', 'CANCELLED', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, '2026-09-11 04:37:38.478612+00', '2026-09-11 04:37:38.478612+00');
INSERT INTO operational.trip VALUES (1, 'TRP-2026-00851', 'SI-2026-00851', 'SL05', 'B-04', 'CLOSED', 'PUMP_ASHORE', '2026-07-18 15:00:00+00', '2026-07-19 05:00:00+00', '2026-07-19 11:30:00+00', '2026-07-19 12:00:00+00', '2026-07-19 18:00:00+00', '2026-07-19 20:10:00+00', '2026-07-20 22:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (2, 'TRP-2026-00852', 'SI-2026-00852', 'SL07', 'B-04', 'CLOSED', 'PUMP_ASHORE', '2026-07-20 01:00:00+00', '2026-07-20 15:00:00+00', '2026-07-20 21:30:00+00', '2026-07-20 22:00:00+00', '2026-07-21 04:00:00+00', '2026-07-21 06:10:00+00', '2026-07-22 08:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (3, 'TRP-2026-00853', 'SI-2026-00853', 'B07', 'B-04', 'CLOSED', 'BOTTOM_DUMP', '2026-07-21 05:00:00+00', '2026-07-21 20:00:00+00', '2026-07-22 03:00:00+00', '2026-07-22 03:30:00+00', '2026-07-22 10:00:00+00', '2026-07-22 12:10:00+00', '2026-07-23 14:10:00+00', 4900.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (4, 'TRP-2026-00854', 'SI-2026-00854', 'B12', 'B-04', 'CLOSED', 'BOTTOM_DUMP', '2026-07-22 09:00:00+00', '2026-07-23 00:00:00+00', '2026-07-23 07:00:00+00', '2026-07-23 07:30:00+00', '2026-07-23 14:00:00+00', '2026-07-23 16:10:00+00', '2026-07-24 18:10:00+00', 4900.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (5, 'TRP-2026-00855', 'SI-2026-00855', 'LI02', 'B-04', 'CLOSED', 'BOTTOM_DUMP', '2026-07-23 13:00:00+00', '2026-07-23 22:00:00+00', '2026-07-24 04:00:00+00', '2026-07-24 04:30:00+00', '2026-07-24 09:30:00+00', '2026-07-24 11:40:00+00', '2026-07-25 13:40:00+00', 2800.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (6, 'TRP-2026-00856', 'SI-2026-00856', 'SL05', 'B-07', 'CLOSED', 'BOTTOM_DUMP', '2026-07-24 03:00:00+00', '2026-07-24 17:00:00+00', '2026-07-24 23:30:00+00', '2026-07-25 00:00:00+00', '2026-07-25 06:00:00+00', '2026-07-25 08:10:00+00', '2026-07-26 17:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (7, 'TRP-2026-00857', 'SI-2026-00857', 'M03', 'B-04', 'CLOSED', 'BOTTOM_DUMP', '2026-07-24 17:00:00+00', '2026-07-25 07:00:00+00', '2026-07-25 14:00:00+00', '2026-07-25 14:30:00+00', '2026-07-25 20:30:00+00', '2026-07-25 22:40:00+00', '2026-07-27 00:40:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (8, 'TRP-2026-00858', 'SI-2026-00858', 'SL07', 'B-07', 'CLOSED', 'BOTTOM_DUMP', '2026-07-25 19:00:00+00', '2026-07-26 09:00:00+00', '2026-07-26 15:30:00+00', '2026-07-26 16:00:00+00', '2026-07-26 22:00:00+00', '2026-07-27 00:10:00+00', '2026-07-28 09:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (9, 'TRP-2026-00859', 'SI-2026-00859', 'B07', 'B-07', 'CLOSED', 'PUMP_ASHORE', '2026-07-26 23:00:00+00', '2026-07-27 14:00:00+00', '2026-07-27 21:00:00+00', '2026-07-27 21:30:00+00', '2026-07-28 04:00:00+00', '2026-07-28 06:10:00+00', '2026-07-29 15:10:00+00', 4900.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (10, 'TRP-2026-00860', 'SI-2026-00860', 'B12', 'B-07', 'CLOSED', 'PUMP_ASHORE', '2026-07-27 03:00:00+00', '2026-07-27 18:00:00+00', '2026-07-28 01:00:00+00', '2026-07-28 01:30:00+00', '2026-07-28 08:00:00+00', '2026-07-28 10:10:00+00', '2026-07-29 19:10:00+00', 4900.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (11, 'TRP-2026-00861', 'SI-2026-00861', 'LI02', 'B-07', 'CLOSED', 'PUMP_ASHORE', '2026-07-28 07:00:00+00', '2026-07-28 16:00:00+00', '2026-07-28 22:00:00+00', '2026-07-28 22:30:00+00', '2026-07-29 03:30:00+00', '2026-07-29 05:40:00+00', '2026-07-30 14:40:00+00', 2800.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (12, 'TRP-2026-00862', 'SI-2026-00862', 'M03', 'B-07', 'CLOSED', 'PUMP_ASHORE', '2026-07-29 11:00:00+00', '2026-07-30 01:00:00+00', '2026-07-30 08:00:00+00', '2026-07-30 08:30:00+00', '2026-07-30 14:30:00+00', '2026-07-30 16:40:00+00', '2026-08-01 01:40:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (13, 'TRP-2026-00863', 'SI-2026-00863', 'SL09', 'B-04', 'CLOSED', 'PUMP_ASHORE', '2026-07-29 11:00:00+00', '2026-07-30 01:00:00+00', '2026-07-30 07:30:00+00', '2026-07-30 08:00:00+00', '2026-07-30 14:00:00+00', '2026-07-30 16:10:00+00', '2026-07-31 18:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (14, 'TRP-2026-00864', 'SI-2026-00864', 'SL07', 'B-04', 'CLOSED', 'PUMP_ASHORE', '2026-07-30 13:00:00+00', '2026-07-31 03:00:00+00', '2026-07-31 09:30:00+00', '2026-07-31 10:00:00+00', '2026-07-31 16:00:00+00', '2026-07-31 18:10:00+00', '2026-08-02 10:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (15, 'TRP-2026-00865', 'SI-2026-00865', 'B07', 'B-04', 'CLOSED', 'BOTTOM_DUMP', '2026-07-31 17:00:00+00', '2026-08-01 08:00:00+00', '2026-08-01 15:00:00+00', '2026-08-01 15:30:00+00', '2026-08-01 22:00:00+00', '2026-08-02 00:10:00+00', '2026-08-03 16:10:00+00', 4900.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (16, 'TRP-2026-00866', 'SI-2026-00866', 'B12', 'B-04', 'CLOSED', 'BOTTOM_DUMP', '2026-08-01 21:00:00+00', '2026-08-02 12:00:00+00', '2026-08-02 19:00:00+00', '2026-08-02 19:30:00+00', '2026-08-03 02:00:00+00', '2026-08-03 04:10:00+00', '2026-08-04 20:10:00+00', 4900.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (17, 'TRP-2026-00867', 'SI-2026-00867', 'LI02', 'B-04', 'CLOSED', 'BOTTOM_DUMP', '2026-08-02 01:00:00+00', '2026-08-02 10:00:00+00', '2026-08-02 16:00:00+00', '2026-08-02 16:30:00+00', '2026-08-02 21:30:00+00', '2026-08-02 23:40:00+00', '2026-08-04 15:40:00+00', 2800.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (18, 'TRP-2026-00868', 'SI-2026-00868', 'M03', 'B-04', 'CLOSED', 'BOTTOM_DUMP', '2026-08-03 05:00:00+00', '2026-08-03 19:00:00+00', '2026-08-04 02:00:00+00', '2026-08-04 02:30:00+00', '2026-08-04 08:30:00+00', '2026-08-04 10:40:00+00', '2026-08-06 02:40:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (19, 'TRP-2026-00869', 'SI-2026-00869', 'SL07', 'B-07', 'CLOSED', 'PUMP_ASHORE', '2026-08-04 07:00:00+00', '2026-08-04 21:00:00+00', '2026-08-05 03:30:00+00', '2026-08-05 04:00:00+00', '2026-08-05 10:00:00+00', '2026-08-05 12:10:00+00', '2026-08-07 11:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (20, 'TRP-2026-00870', 'SI-2026-00870', 'SL09', 'B-07', 'CLOSED', 'BOTTOM_DUMP', '2026-08-04 19:00:00+00', '2026-08-05 09:00:00+00', '2026-08-05 15:30:00+00', '2026-08-05 16:00:00+00', '2026-08-05 22:00:00+00', '2026-08-06 00:10:00+00', '2026-08-07 09:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (21, 'TRP-2026-00871', 'SI-2026-00871', 'B07', 'B-07', 'CLOSED', 'BOTTOM_DUMP', '2026-08-05 11:00:00+00', '2026-08-06 02:00:00+00', '2026-08-06 09:00:00+00', '2026-08-06 09:30:00+00', '2026-08-06 16:00:00+00', '2026-08-06 18:10:00+00', '2026-08-08 17:10:00+00', 4900.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (22, 'TRP-2026-00872', 'SI-2026-00872', 'SL02', 'B-04', 'CLOSED', 'PUMP_ASHORE', '2026-08-06 09:00:00+00', '2026-08-06 23:00:00+00', '2026-08-07 05:30:00+00', '2026-08-07 06:00:00+00', '2026-08-07 12:00:00+00', '2026-08-07 14:10:00+00', '2026-08-08 16:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (23, 'TRP-2026-00873', 'SI-2026-00873', 'B12', 'B-07', 'CLOSED', 'BOTTOM_DUMP', '2026-08-06 15:00:00+00', '2026-08-07 06:00:00+00', '2026-08-07 13:00:00+00', '2026-08-07 13:30:00+00', '2026-08-07 20:00:00+00', '2026-08-07 22:10:00+00', '2026-08-09 21:10:00+00', 4900.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (24, 'TRP-2026-00874', 'SI-2026-00874', 'LI02', 'B-07', 'CLOSED', 'BOTTOM_DUMP', '2026-08-07 19:00:00+00', '2026-08-08 04:00:00+00', '2026-08-08 10:00:00+00', '2026-08-08 10:30:00+00', '2026-08-08 15:30:00+00', '2026-08-08 17:40:00+00', '2026-08-10 16:40:00+00', 2800.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (25, 'TRP-2026-00875', 'SI-2026-00875', 'M03', 'B-07', 'CLOSED', 'BOTTOM_DUMP', '2026-08-08 23:00:00+00', '2026-08-09 13:00:00+00', '2026-08-09 20:00:00+00', '2026-08-09 20:30:00+00', '2026-08-10 02:30:00+00', '2026-08-10 04:40:00+00', '2026-08-12 03:40:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (26, 'TRP-2026-00876', 'SI-2026-00876', 'SL07', 'B-04', 'CLOSED', 'BOTTOM_DUMP', '2026-08-09 21:00:00+00', '2026-08-10 11:00:00+00', '2026-08-10 17:30:00+00', '2026-08-10 18:00:00+00', '2026-08-11 00:00:00+00', '2026-08-11 02:10:00+00', '2026-08-12 10:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (27, 'TRP-2026-00877', 'SI-2026-00877', 'SL09', 'B-04', 'CLOSED', 'PUMP_ASHORE', '2026-08-10 05:00:00+00', '2026-08-10 19:00:00+00', '2026-08-11 01:30:00+00', '2026-08-11 02:00:00+00', '2026-08-11 08:00:00+00', '2026-08-11 10:10:00+00', '2026-08-13 02:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');
INSERT INTO operational.trip VALUES (28, 'TRP-2026-00878', 'SI-2026-00878', 'SL02', 'B-07', 'CLOSED', 'BOTTOM_DUMP', '2026-08-12 17:00:00+00', '2026-08-13 07:00:00+00', '2026-08-13 13:30:00+00', '2026-08-13 14:00:00+00', '2026-08-13 20:00:00+00', '2026-08-13 22:10:00+00', '2026-08-15 07:10:00+00', 5400.000, NULL, NULL, true, NULL, '2026-09-11 04:37:38.716843+00', '2026-09-11 04:37:38.716843+00');


--
-- Data for Name: bap; Type: TABLE DATA; Schema: commercial; Owner: -
--

INSERT INTO commercial.bap VALUES (86, 'BAP-2026-0086', 903, 4982.558, 'SIGNED', 'Capt. Dedi (Nakhoda MV Sinar Laut 09)', '2026-09-04 00:10:00+00', 'Ir. Rahmat (PT PRN)', '2026-09-04 00:08:00+00', 'Budi Santoso', '2026-09-04 00:09:00+00', '2026-09-04 00:12:00+00', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00', NULL, NULL, NULL);
INSERT INTO commercial.bap VALUES (87, 'BAP-2026-0087', 907, 5371.800, 'SIGNED', 'H. Bakti (Nakhoda MV Sinar Laut 02)', '2026-09-07 07:35:00+00', 'Ir. Rahmat (PT PRN)', '2026-09-07 07:33:00+00', 'Budi Santoso', '2026-09-07 07:34:00+00', '2026-09-07 07:36:00+00', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00', NULL, NULL, NULL);
INSERT INTO commercial.bap VALUES (88, 'BAP-2026-0088', 910, 3900.000, 'CORRECTED', 'H. Andi (Nakhoda MV Sinar Laut 05)', '2026-09-09 19:12:00+00', 'Ir. Sinta Wijaya (PT PSR)', '2026-09-09 19:13:00+00', 'Budi Santoso', '2026-09-09 19:14:00+00', '2026-09-09 19:15:00+00', NULL, '2026-09-11 04:37:38.481079+00', '2026-09-11 04:37:38.481079+00', NULL, NULL, NULL);
INSERT INTO commercial.bap VALUES (85, 'BAP-2026-0085', 899, 5250.000, 'SIGNED', 'H. Andi (Nakhoda MV Sinar Laut 05)', '2026-09-01 22:10:00+00', 'Ir. Rahmat (PT PRN)', '2026-09-01 22:08:00+00', 'Budi Santoso', '2026-09-01 22:09:00+00', '2026-09-01 22:12:00+00', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00', NULL, NULL, NULL);


--
-- Data for Name: deposit_transaction; Type: TABLE DATA; Schema: buyer; Owner: -
--

INSERT INTO buyer.deposit_transaction VALUES (1, 1, 'TOP_UP', 700000000.00, NULL, NULL, '2026-01-12', 'TRF-2026-0117', 'finance', 1, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO buyer.deposit_transaction VALUES (2, 1, 'DEDUCTION', 112875000.00, 899, 85, '2026-09-02', 'BAP-2026-0085', 'system', 2, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO buyer.deposit_transaction VALUES (3, 1, 'DEDUCTION', 107124997.00, 903, 86, '2026-09-04', 'BAP-2026-0086', 'system', 3, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO buyer.deposit_transaction VALUES (4, 1, 'ADJUSTMENT', 3.00, NULL, NULL, '2026-09-04', 'KOREKSI-PEMBULATAN-0086', 'finance', 4, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO buyer.deposit_transaction VALUES (5, 1, 'DEDUCTION', 115493700.00, 907, 87, '2026-09-07', 'BAP-2026-0087', 'system', 5, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO buyer.deposit_transaction VALUES (6, 2, 'TOP_UP', 50000000.00, NULL, NULL, '2026-09-01', 'TRF-2026-0301', 'finance', 6, NULL, '2026-09-11 04:37:38.474519+00', '2026-09-11 04:37:38.474519+00');
INSERT INTO buyer.deposit_transaction VALUES (7, 2, 'DEDUCTION', 50000000.00, 910, 88, '2026-09-10', 'BAP-2026-0088', 'system', 7, NULL, '2026-09-11 04:37:38.483379+00', '2026-09-11 04:37:38.483379+00');


--
-- Data for Name: site; Type: TABLE DATA; Schema: buyer; Owner: -
--

INSERT INTO buyer.site VALUES (1, 'B-PRN', 'SITE-G', 'Site bongkar utama SC-2026-014');
INSERT INTO buyer.site VALUES (2, 'B-PRN', 'ETAP-2', 'Etap lanjutan reklamasi');
INSERT INTO buyer.site VALUES (3, 'B-WKR', 'MARINA-JAYA', 'Pengisian marina');


--
-- Data for Name: bap_correction; Type: TABLE DATA; Schema: commercial; Owner: -
--

INSERT INTO commercial.bap_correction VALUES (1, 'COR-2026-001', 88, -50.000, 'Kesalahan pembacaan sisa material di hopper pada survey akhir; volume terkoreksi 3.950 → 3.900 m³.', 'finance', '2026-09-12 03:00:00+00', NULL, '2026-09-11 04:37:38.486308+00');


--
-- Data for Name: bap_objection; Type: TABLE DATA; Schema: commercial; Owner: -
--

INSERT INTO commercial.bap_objection VALUES (1, 88, 'Ir. Sinta Wijaya (PT PSR)', '2026-09-10 02:00:00+00', 'Kadar lumpur hasil QA bongkar 6,2% melebihi spek kontrak maks 5% — mohon penyesuaian tagihan.', 'Disepakati: sampel pengujian ulang laboratorium rujukan menunjukkan 4,8% (dalam spek). Tagihan TETAP sesuai BAP; credit note tidak terbit (FR-05-07).', '2026-09-11 08:00:00+00', 'RESOLVED', NULL, '2026-09-11 04:37:38.485244+00');


--
-- Data for Name: qa_sample; Type: TABLE DATA; Schema: commercial; Owner: -
--

INSERT INTO commercial.qa_sample VALUES ('9a000000-0000-0000-0000-00000000a907', 907, 'MUAT', '2026-09-05 06:40:00+00', 'Tim QA Internal', 1, '{"gradasi": "MEDIUM", "mud_content_pct": 2.8, "kadar_organik_pct": 1.2}', 'PASS', NULL, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO commercial.qa_sample VALUES ('9a000000-0000-0000-0000-00000000b907', 907, 'BONGKAR', '2026-09-07 03:00:00+00', 'Tim QA Internal', 1, '{"gradasi": "MEDIUM", "mud_content_pct": 3.1, "kadar_organik_pct": 1.4}', 'PASS', NULL, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO commercial.qa_sample VALUES ('9a000000-0000-0000-0000-00000000a910', 910, 'MUAT', '2026-09-08 01:00:00+00', 'Tim QA Internal', 2, '{"gradasi": "MEDIUM", "mud_content_pct": 3.0, "kadar_organik_pct": 1.3}', 'PASS', NULL, NULL, '2026-09-11 04:37:38.484289+00', '2026-09-11 04:37:38.484289+00');
INSERT INTO commercial.qa_sample VALUES ('9a000000-0000-0000-0000-00000000b910', 910, 'BONGKAR', '2026-09-09 16:30:00+00', 'Tim QA Internal', 2, '{"gradasi": "MEDIUM", "mud_content_pct": 6.2, "kadar_organik_pct": 2.1}', 'FAIL', 'FILED', NULL, '2026-09-11 04:37:38.484289+00', '2026-09-11 04:37:38.484289+00');


--
-- Data for Name: standby_claim; Type: TABLE DATA; Schema: commercial; Owner: -
--

INSERT INTO commercial.standby_claim VALUES (1, 907, 720, 900, 180, 4500000.00, 13500000.00, 'DISPOSED_TAGIH', 'finance', '2026-09-07 08:00:00+00', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO commercial.standby_claim VALUES (2, 910, 720, 120, 0, 4000000.00, 0.00, 'DISPOSED_HANGUS', 'finance', '2026-09-09 22:00:00+00', NULL, '2026-09-11 04:37:38.487835+00', '2026-09-11 04:37:38.487835+00');


--
-- Data for Name: document; Type: TABLE DATA; Schema: document; Owner: -
--

INSERT INTO document.document VALUES (101, 'DOC-SV-MUAT-0899', 'DRAFT_SURVEY', 'Draft Survey MUAT — TRP-2026-0899', 'trip', 899, '/doc/survey/0899-muat.pdf', '2026-09-11 04:37:38.232279+00');
INSERT INTO document.document VALUES (102, 'DOC-BAP-0085', 'BAP', 'BAP-2026-0085 (signed)', 'trip', 899, '/doc/bap/0085.pdf', '2026-09-11 04:37:38.232279+00');
INSERT INTO document.document VALUES (103, 'DOC-SV-MUAT-0903', 'DRAFT_SURVEY', 'Draft Survey MUAT — TRP-2026-0903', 'trip', 903, '/doc/survey/0903-muat.pdf', '2026-09-11 04:37:38.232279+00');
INSERT INTO document.document VALUES (104, 'DOC-BAP-0086', 'BAP', 'BAP-2026-0086 (signed)', 'trip', 903, '/doc/bap/0086.pdf', '2026-09-11 04:37:38.232279+00');
INSERT INTO document.document VALUES (111, 'DOC-SV-MUAT-0907', 'DRAFT_SURVEY', 'Draft Survey MUAT — TRP-2026-0907', 'trip', 907, '/doc/survey/0907-muat.pdf', '2026-09-11 04:37:38.232279+00');
INSERT INTO document.document VALUES (112, 'DOC-SV-AWAL-0907', 'DRAFT_SURVEY', 'Draft Survey AWAL BONGKAR — TRP-2026-0907', 'trip', 907, '/doc/survey/0907-awal.pdf', '2026-09-11 04:37:38.232279+00');
INSERT INTO document.document VALUES (113, 'DOC-SV-AKHIR-0907', 'DRAFT_SURVEY', 'Draft Survey AKHIR BONGKAR — TRP-2026-0907', 'trip', 907, '/doc/survey/0907-akhir.pdf', '2026-09-11 04:37:38.232279+00');
INSERT INTO document.document VALUES (114, 'DOC-BAP-0087', 'BAP', 'BAP-2026-0087 (signed, TTD 3 pihak)', 'trip', 907, '/doc/bap/0087.pdf', '2026-09-11 04:37:38.232279+00');
INSERT INTO document.document VALUES (115, 'DOC-SOF-0907', 'SOF', 'Statement of Facts — TRP-2026-0907', 'trip', 907, '/doc/sof/0907.pdf', '2026-09-11 04:37:38.232279+00');
INSERT INTO document.document VALUES (116, 'DOC-QA-0907', 'QA', 'QA Report Muat — TRP-2026-0907', 'trip', 907, '/doc/qa/0907.pdf', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: document_link; Type: TABLE DATA; Schema: document; Owner: -
--

INSERT INTO document.document_link VALUES (101, 'trip', 899, false, '2026-09-11 04:37:38.33738+00');
INSERT INTO document.document_link VALUES (102, 'trip', 899, false, '2026-09-11 04:37:38.33738+00');
INSERT INTO document.document_link VALUES (103, 'trip', 903, false, '2026-09-11 04:37:38.33738+00');
INSERT INTO document.document_link VALUES (104, 'trip', 903, false, '2026-09-11 04:37:38.33738+00');
INSERT INTO document.document_link VALUES (111, 'trip', 907, false, '2026-09-11 04:37:38.33738+00');
INSERT INTO document.document_link VALUES (112, 'trip', 907, false, '2026-09-11 04:37:38.33738+00');
INSERT INTO document.document_link VALUES (113, 'trip', 907, false, '2026-09-11 04:37:38.33738+00');
INSERT INTO document.document_link VALUES (114, 'trip', 907, false, '2026-09-11 04:37:38.33738+00');
INSERT INTO document.document_link VALUES (115, 'trip', 907, false, '2026-09-11 04:37:38.33738+00');
INSERT INTO document.document_link VALUES (116, 'trip', 907, false, '2026-09-11 04:37:38.33738+00');


--
-- Data for Name: mon_parameter; Type: TABLE DATA; Schema: enviro; Owner: -
--

INSERT INTO enviro.mon_parameter VALUES ('TURBIDITY', 'Turbidity', 'NTU', 'HIDRO', true, 120.000000, 'ASEAN MWQC [VERIFIKASI]', 90.00, NULL, true, '2026-09-11 04:37:38.083011+00', '2026-09-11 04:37:38.083011+00');
INSERT INTO enviro.mon_parameter VALUES ('TSS', 'Total Suspended Solid', 'mg/L', 'HIDRO', true, 80.000000, 'ASEAN MWQC [VERIFIKASI]', 90.00, NULL, true, '2026-09-11 04:37:38.083011+00', '2026-09-11 04:37:38.083011+00');
INSERT INTO enviro.mon_parameter VALUES ('DO', 'Dissolved Oxygen (minimum)', 'mg/L', 'HIDRO', true, 5.000000, 'ASEAN MWQC [VERIFIKASI]', 90.00, NULL, true, '2026-09-11 04:37:38.083011+00', '2026-09-11 04:37:38.083011+00');
INSERT INTO enviro.mon_parameter VALUES ('SALINITY', 'Salinitas (maksimum)', 'permil', 'HIDRO', true, 34.000000, 'ASEAN MWQC [VERIFIKASI]', 90.00, NULL, true, '2026-09-11 04:37:38.083011+00', '2026-09-11 04:37:38.083011+00');
INSERT INTO enviro.mon_parameter VALUES ('PH', 'pH (rentang 7,0-8,5)', '-', 'HIDRO', true, NULL, 'ASEAN MWQC [VERIFIKASI]', 90.00, NULL, true, '2026-09-11 04:37:38.083011+00', '2026-09-11 04:37:38.083011+00');
INSERT INTO enviro.mon_parameter VALUES ('MINYAK_LEMAK', 'Minyak dan Lemak', 'mg/L', 'AIR', true, 5.000000, 'Kepmen LH 51/2004 air laut biota [VERIFIKASI]', 90.00, NULL, true, '2026-09-11 04:37:38.795507+00', '2026-09-11 04:37:38.795507+00');
INSERT INTO enviro.mon_parameter VALUES ('AMONIA_TOTAL', 'Amonia Total (N-NH3)', 'mg/L', 'AIR', true, 0.300000, 'Kepmen LH 51/2004 air laut biota [VERIFIKASI]', 90.00, NULL, true, '2026-09-11 04:37:38.795507+00', '2026-09-11 04:37:38.795507+00');
INSERT INTO enviro.mon_parameter VALUES ('ORTOFOSFAT', 'Orto-fosfat (PO4-P)', 'mg/L', 'AIR', true, 0.015000, 'Kepmen LH 51/2004 air laut biota [VERIFIKASI]', 90.00, NULL, true, '2026-09-11 04:37:38.795507+00', '2026-09-11 04:37:38.795507+00');
INSERT INTO enviro.mon_parameter VALUES ('IKAL', 'Indeks Kualitas Air Laut — komposit 5 parameter (PermenLHK 27/2021)', 'indeks', 'AIR', false, 50.000000, 'PermenLHK 27/2021 Tabel 2.2 · ambang alert internal 50 (KURANG)', 90.00, NULL, true, '2026-09-11 04:37:38.795507+00', '2026-09-11 04:37:38.795507+00');


--
-- Data for Name: ews_event; Type: TABLE DATA; Schema: enviro; Owner: -
--

INSERT INTO enviro.ews_event VALUES (1, 'ST-03', 'TURBIDITY', 'WARNING', 'THRESHOLD', '{"pct": 93.3, "value": 112, "warning": 108}', '{"telegram": ["ops-dispatch"]}', 'R19', NULL, NULL, NULL, NULL, '2026-09-05 23:10:00+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.ews_event VALUES (2, 'ST-03', 'TURBIDITY', 'EXCEEDED', 'THRESHOLD', '{"pct": 106.7, "value": 128, "standard": 120}', '{"email": ["env@ppteluk.co.id"], "telegram": ["ops-dispatch", "nakhoda:SL02"]}', 'R19', NULL, NULL, NULL, NULL, '2026-09-06 23:05:00+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.ews_event VALUES (3, 'ST-03', 'IKAL', 'EXCEEDED', 'COMPOSITE', '{"ikal": 39.37, "param": {"DO": 4.6, "TSS": 85, "ORTOFOSFAT": 0.068, "AMONIA_TOTAL": 0.42, "MINYAK_LEMAK": 3.2}, "periode": "2026-06", "kategori": "KURANG"}', '{"email": ["env@ppteluk.co.id"], "telegram": ["ops-dispatch"]}', NULL, NULL, NULL, '2026-08-05 01:00:00+00', NULL, '2026-09-11 04:37:38.801287+00', '2026-09-11 04:37:38.801287+00');
INSERT INTO enviro.ews_event VALUES (4, 'ST-03', 'IKAL', 'EXCEEDED', 'COMPOSITE', '{"ikal": 36.16, "param": {"DO": 4.4, "TSS": 92, "ORTOFOSFAT": 0.075, "AMONIA_TOTAL": 0.46, "MINYAK_LEMAK": 3.5}, "periode": "2026-07", "kategori": "KURANG"}', '{"email": ["env@ppteluk.co.id"], "telegram": ["ops-dispatch"]}', NULL, NULL, NULL, NULL, NULL, '2026-09-11 04:37:38.802626+00', '2026-09-11 04:37:38.802626+00');


--
-- Data for Name: mon_report; Type: TABLE DATA; Schema: enviro; Owner: -
--

INSERT INTO enviro.mon_report VALUES (1, '2026-II', 'RKL_RPL', '2026-09-07 03:00:00+00', NULL, NULL, NULL, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: station; Type: TABLE DATA; Schema: enviro; Owner: -
--

INSERT INTO enviro.station VALUES ('ST-01', 'Teluk Utara (Referensi)', 'REFERENSI', '0101000020E61000006666666666865A4000000000000017C0');
INSERT INTO enviro.station VALUES ('ST-02', 'Perairan Site G', 'DUMPING', '0101000020E6100000F6285C8FC2955A40D7A3703D0AD717C0');
INSERT INTO enviro.station VALUES ('ST-03', 'Muara Blok B-04', 'MUARA', '0101000020E6100000EC51B81E857B5A403D0AD7A3703D17C0');


--
-- Data for Name: mon_schedule; Type: TABLE DATA; Schema: enviro; Owner: -
--

INSERT INTO enviro.mon_schedule VALUES (2, 'TSS', 'ST-03', 'HARIAN', '2026-09-08', true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.mon_schedule VALUES (5, 'PH', 'ST-01', 'SEMESTERAN', '2026-10-01', false, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.mon_schedule VALUES (4, 'DO', 'ST-02', 'HARIAN', '2026-09-08', true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.mon_schedule VALUES (1, 'TURBIDITY', 'ST-03', 'HARIAN', '2026-09-08', true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.mon_schedule VALUES (3, 'SALINITY', 'ST-02', 'HARIAN', '2026-09-08', true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: info; Type: TABLE DATA; Schema: partner; Owner: -
--

INSERT INTO partner.info VALUES ('P-SMI', 'PT Samudra Mitra', 'CHARTER', 'ops@samudramitra.co.id', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.info VALUES ('P-BHL', 'PT Bahari Lines', 'CHARTER', 'ops@baharilines.co.id', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.info VALUES ('P-MLT', 'PT Mulya Trans', 'CHARTER_TC', 'finance@mulyatrans.co.id', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.info VALUES ('P-DLM', 'PT Delta Marine', 'LAB_ENVIRO', 'lab@deltamarine.co.id', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: mon_work_order; Type: TABLE DATA; Schema: enviro; Owner: -
--

INSERT INTO enviro.mon_work_order VALUES (121, 'WO-MON-2026-0121', 'P-DLM', 'BUOY_DOWNLOAD', '2026-09-07', 'COMPLETED', '{ST-02,ST-03}', '{TURBIDITY,TSS,SALINITY,DO}', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.mon_work_order VALUES (123, 'WO-MON-2026-0123', 'P-DLM', 'SAMPLING', '2026-09-10', 'ISSUED', '{ST-01,ST-02,ST-03}', '{TURBIDITY,TSS,SALINITY,DO,PH}', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: reading_detail; Type: TABLE DATA; Schema: enviro; Owner: -
--

INSERT INTO enviro.reading_detail VALUES (1, 'ST-03', 'TURBIDITY', '2026-08-30 23:00:00+00', 98.000000, 'NTU', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (2, 'ST-03', 'TSS', '2026-09-01 23:00:00+00', 66.000000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (3, 'ST-03', 'TURBIDITY', '2026-08-31 23:00:00+00', 99.000000, 'NTU', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (4, 'ST-03', 'TURBIDITY', '2026-08-29 23:00:00+00', 96.000000, 'NTU', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (5, 'ST-01', 'PH', '2026-09-06 02:00:00+00', 8.000000, '-', 'LAB', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (6, 'ST-02', 'DO', '2026-08-31 23:00:00+00', 5.800000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (7, 'ST-02', 'SALINITY', '2026-08-31 23:00:00+00', 28.100000, 'permil', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (8, 'ST-03', 'TSS', '2026-09-02 23:00:00+00', 68.000000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (9, 'ST-03', 'TSS', '2026-09-04 23:00:00+00', 71.000000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (10, 'ST-03', 'TURBIDITY', '2026-09-03 23:00:00+00', 106.000000, 'NTU', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (11, 'ST-03', 'TURBIDITY', '2026-09-05 23:00:00+00', 118.000000, 'NTU', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (12, 'ST-03', 'TURBIDITY', '2026-09-06 23:00:00+00', 128.000000, 'NTU', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (13, 'ST-02', 'DO', '2026-09-06 23:00:00+00', 5.600000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (14, 'ST-02', 'SALINITY', '2026-09-06 23:00:00+00', 28.900000, 'permil', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (15, 'ST-03', 'TURBIDITY', '2026-09-04 23:00:00+00', 112.000000, 'NTU', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (16, 'ST-03', 'TSS', '2026-09-05 23:00:00+00', 73.000000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (17, 'ST-03', 'TSS', '2026-09-03 23:00:00+00', 69.000000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (18, 'ST-02', 'SALINITY', '2026-09-04 23:00:00+00', 28.600000, 'permil', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (19, 'ST-02', 'DO', '2026-09-04 23:00:00+00', 5.500000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (20, 'ST-03', 'TSS', '2026-09-06 23:00:00+00', 76.000000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (21, 'ST-03', 'TSS', '2026-08-31 23:00:00+00', 64.000000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (22, 'ST-03', 'TURBIDITY', '2026-09-01 23:00:00+00', 101.000000, 'NTU', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (23, 'ST-01', 'PH', '2026-09-07 02:00:00+00', 8.100000, '-', 'LAB', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (24, 'ST-02', 'DO', '2026-09-02 23:00:00+00', 5.600000, 'mg/L', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (25, 'ST-02', 'SALINITY', '2026-09-02 23:00:00+00', 28.400000, 'permil', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (26, 'ST-03', 'TURBIDITY', '2026-09-02 23:00:00+00', 104.000000, 'NTU', 'BUOY', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (27, 'ST-01', 'PH', '2026-09-05 02:00:00+00', 8.100000, '-', 'LAB', NULL, 'VALIDATED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO enviro.reading_detail VALUES (28, 'ST-01', 'TSS', '2026-04-05 01:00:00+00', 12.000000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (29, 'ST-01', 'DO', '2026-04-05 01:00:00+00', 6.800000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (30, 'ST-01', 'MINYAK_LEMAK', '2026-04-05 01:00:00+00', 0.800000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (31, 'ST-01', 'AMONIA_TOTAL', '2026-04-05 01:00:00+00', 0.055000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (32, 'ST-01', 'ORTOFOSFAT', '2026-04-05 01:00:00+00', 0.008000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (33, 'ST-01', 'TSS', '2026-05-05 01:00:00+00', 11.000000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (34, 'ST-01', 'DO', '2026-05-05 01:00:00+00', 6.900000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (35, 'ST-01', 'MINYAK_LEMAK', '2026-05-05 01:00:00+00', 0.700000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (36, 'ST-01', 'AMONIA_TOTAL', '2026-05-05 01:00:00+00', 0.050000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (37, 'ST-01', 'ORTOFOSFAT', '2026-05-05 01:00:00+00', 0.007000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (38, 'ST-01', 'TSS', '2026-06-05 01:00:00+00', 13.000000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (39, 'ST-01', 'DO', '2026-06-05 01:00:00+00', 6.600000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (40, 'ST-01', 'MINYAK_LEMAK', '2026-06-05 01:00:00+00', 0.900000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (41, 'ST-01', 'AMONIA_TOTAL', '2026-06-05 01:00:00+00', 0.060000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (42, 'ST-01', 'ORTOFOSFAT', '2026-06-05 01:00:00+00', 0.009000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (43, 'ST-01', 'TSS', '2026-07-05 01:00:00+00', 12.500000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (44, 'ST-01', 'DO', '2026-07-05 01:00:00+00', 6.700000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (45, 'ST-01', 'MINYAK_LEMAK', '2026-07-05 01:00:00+00', 0.850000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (46, 'ST-01', 'AMONIA_TOTAL', '2026-07-05 01:00:00+00', 0.058000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (47, 'ST-01', 'ORTOFOSFAT', '2026-07-05 01:00:00+00', 0.008500, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (48, 'ST-01', 'TSS', '2026-08-05 01:00:00+00', 14.000000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (49, 'ST-01', 'DO', '2026-08-05 01:00:00+00', 6.400000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (50, 'ST-01', 'MINYAK_LEMAK', '2026-08-05 01:00:00+00', 1.000000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (51, 'ST-01', 'AMONIA_TOTAL', '2026-08-05 01:00:00+00', 0.070000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (52, 'ST-01', 'ORTOFOSFAT', '2026-08-05 01:00:00+00', 0.010000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (53, 'ST-01', 'TSS', '2026-09-05 01:00:00+00', 15.000000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (54, 'ST-01', 'DO', '2026-09-05 01:00:00+00', 6.000000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (55, 'ST-01', 'MINYAK_LEMAK', '2026-09-05 01:00:00+00', 2.000000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (56, 'ST-01', 'AMONIA_TOTAL', '2026-09-05 01:00:00+00', 0.100000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (57, 'ST-01', 'ORTOFOSFAT', '2026-09-05 01:00:00+00', 0.020000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.796158+00', '2026-09-11 04:37:38.796158+00');
INSERT INTO enviro.reading_detail VALUES (58, 'ST-02', 'TSS', '2026-04-05 01:00:00+00', 38.000000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (59, 'ST-02', 'DO', '2026-04-05 01:00:00+00', 5.600000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (60, 'ST-02', 'MINYAK_LEMAK', '2026-04-05 01:00:00+00', 1.600000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (61, 'ST-02', 'AMONIA_TOTAL', '2026-04-05 01:00:00+00', 0.180000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (62, 'ST-02', 'ORTOFOSFAT', '2026-04-05 01:00:00+00', 0.030000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (63, 'ST-02', 'TSS', '2026-05-05 01:00:00+00', 42.000000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (64, 'ST-02', 'DO', '2026-05-05 01:00:00+00', 5.500000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (65, 'ST-02', 'MINYAK_LEMAK', '2026-05-05 01:00:00+00', 1.800000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (66, 'ST-02', 'AMONIA_TOTAL', '2026-05-05 01:00:00+00', 0.200000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (67, 'ST-02', 'ORTOFOSFAT', '2026-05-05 01:00:00+00', 0.033000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (68, 'ST-02', 'TSS', '2026-06-05 01:00:00+00', 50.000000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (69, 'ST-02', 'DO', '2026-06-05 01:00:00+00', 5.300000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (70, 'ST-02', 'MINYAK_LEMAK', '2026-06-05 01:00:00+00', 2.100000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (71, 'ST-02', 'AMONIA_TOTAL', '2026-06-05 01:00:00+00', 0.240000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (72, 'ST-02', 'ORTOFOSFAT', '2026-06-05 01:00:00+00', 0.038000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (73, 'ST-02', 'TSS', '2026-07-05 01:00:00+00', 47.000000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (74, 'ST-02', 'DO', '2026-07-05 01:00:00+00', 5.400000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (75, 'ST-02', 'MINYAK_LEMAK', '2026-07-05 01:00:00+00', 2.000000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (76, 'ST-02', 'AMONIA_TOTAL', '2026-07-05 01:00:00+00', 0.220000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (77, 'ST-02', 'ORTOFOSFAT', '2026-07-05 01:00:00+00', 0.036000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (78, 'ST-02', 'TSS', '2026-08-05 01:00:00+00', 44.000000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (79, 'ST-02', 'DO', '2026-08-05 01:00:00+00', 5.500000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (80, 'ST-02', 'MINYAK_LEMAK', '2026-08-05 01:00:00+00', 1.900000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (81, 'ST-02', 'AMONIA_TOTAL', '2026-08-05 01:00:00+00', 0.210000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (82, 'ST-02', 'ORTOFOSFAT', '2026-08-05 01:00:00+00', 0.034000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (83, 'ST-02', 'TSS', '2026-09-05 01:00:00+00', 40.000000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (84, 'ST-02', 'DO', '2026-09-05 01:00:00+00', 5.600000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (85, 'ST-02', 'MINYAK_LEMAK', '2026-09-05 01:00:00+00', 1.700000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (86, 'ST-02', 'AMONIA_TOTAL', '2026-09-05 01:00:00+00', 0.190000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (87, 'ST-02', 'ORTOFOSFAT', '2026-09-05 01:00:00+00', 0.031000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.797686+00', '2026-09-11 04:37:38.797686+00');
INSERT INTO enviro.reading_detail VALUES (88, 'ST-03', 'TSS', '2026-04-05 01:00:00+00', 55.000000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (89, 'ST-03', 'DO', '2026-04-05 01:00:00+00', 5.200000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (90, 'ST-03', 'MINYAK_LEMAK', '2026-04-05 01:00:00+00', 2.400000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (91, 'ST-03', 'AMONIA_TOTAL', '2026-04-05 01:00:00+00', 0.280000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (92, 'ST-03', 'ORTOFOSFAT', '2026-04-05 01:00:00+00', 0.045000, 'mg/L', 'LAB', 'IKAL-202604', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (93, 'ST-03', 'TSS', '2026-05-05 01:00:00+00', 62.000000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (94, 'ST-03', 'DO', '2026-05-05 01:00:00+00', 5.000000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (95, 'ST-03', 'MINYAK_LEMAK', '2026-05-05 01:00:00+00', 2.700000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (96, 'ST-03', 'AMONIA_TOTAL', '2026-05-05 01:00:00+00', 0.320000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (97, 'ST-03', 'ORTOFOSFAT', '2026-05-05 01:00:00+00', 0.052000, 'mg/L', 'LAB', 'IKAL-202605', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (98, 'ST-03', 'TSS', '2026-06-05 01:00:00+00', 85.000000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (99, 'ST-03', 'DO', '2026-06-05 01:00:00+00', 4.600000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (100, 'ST-03', 'MINYAK_LEMAK', '2026-06-05 01:00:00+00', 3.200000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (101, 'ST-03', 'AMONIA_TOTAL', '2026-06-05 01:00:00+00', 0.420000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (102, 'ST-03', 'ORTOFOSFAT', '2026-06-05 01:00:00+00', 0.068000, 'mg/L', 'LAB', 'IKAL-202606', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (103, 'ST-03', 'TSS', '2026-07-05 01:00:00+00', 92.000000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (104, 'ST-03', 'DO', '2026-07-05 01:00:00+00', 4.400000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (105, 'ST-03', 'MINYAK_LEMAK', '2026-07-05 01:00:00+00', 3.500000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (106, 'ST-03', 'AMONIA_TOTAL', '2026-07-05 01:00:00+00', 0.460000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (107, 'ST-03', 'ORTOFOSFAT', '2026-07-05 01:00:00+00', 0.075000, 'mg/L', 'LAB', 'IKAL-202607', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (108, 'ST-03', 'TSS', '2026-08-05 01:00:00+00', 68.000000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (109, 'ST-03', 'DO', '2026-08-05 01:00:00+00', 4.900000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (110, 'ST-03', 'MINYAK_LEMAK', '2026-08-05 01:00:00+00', 2.900000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (111, 'ST-03', 'AMONIA_TOTAL', '2026-08-05 01:00:00+00', 0.350000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (112, 'ST-03', 'ORTOFOSFAT', '2026-08-05 01:00:00+00', 0.058000, 'mg/L', 'LAB', 'IKAL-202608', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (113, 'ST-03', 'TSS', '2026-09-05 01:00:00+00', 58.000000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (114, 'ST-03', 'DO', '2026-09-05 01:00:00+00', 5.100000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (115, 'ST-03', 'MINYAK_LEMAK', '2026-09-05 01:00:00+00', 2.500000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (116, 'ST-03', 'AMONIA_TOTAL', '2026-09-05 01:00:00+00', 0.300000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');
INSERT INTO enviro.reading_detail VALUES (117, 'ST-03', 'ORTOFOSFAT', '2026-09-05 01:00:00+00', 0.048000, 'mg/L', 'LAB', 'IKAL-202609', 'VALIDATED', NULL, '2026-09-11 04:37:38.798632+00', '2026-09-11 04:37:38.798632+00');


--
-- Data for Name: remediation; Type: TABLE DATA; Schema: enviro; Owner: -
--

INSERT INTO enviro.remediation VALUES (1, 'EWS', 2, 'R19 — kurangi intensitas pengerukan B-04 50% · pasang silt curtain · sampling verifikasi H+3 (10 Sep)', '2026-09-07 00:00:00+00', 'IN_PROGRESS', NULL, NULL, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: journal; Type: TABLE DATA; Schema: financial; Owner: -
--

INSERT INTO financial.journal VALUES (98, 'J-2026-09-0098', '2026-09-02', 'partner.statement_line', '259', 'Hak partner TRP-2026-0899 (basis BAP-2026-0085)', 63000000.00);
INSERT INTO financial.journal VALUES (104, 'J-2026-09-0104', '2026-09-04', 'partner.statement_line', '260', 'Hak partner TRP-2026-0903 (basis BAP-2026-0086)', 38000000.00);
INSERT INTO financial.journal VALUES (112, 'J-2026-09-0112', '2026-09-07', 'commercial.bap', 'BAP-2026-0087', 'Pengakuan pendapatan pasir TRP-2026-0907', 115493700.00);
INSERT INTO financial.journal VALUES (113, 'J-2026-09-0113', '2026-09-07', 'commercial.bap', 'BAP-2026-0087', 'Pemotongan deposit SC-2026-014', 115493700.00);
INSERT INTO financial.journal VALUES (114, 'J-2026-09-0114', '2026-09-07', 'partner.statement_line', '261', 'Hak partner TRP-2026-0907 (basis BAP-2026-0087)', 64461600.00);
INSERT INTO financial.journal VALUES (115, 'J-2026-09-0115', '2026-09-07', 'financial.pnbp_charge', '79', 'PNBP per trip TRP-2026-0907 (basis BAP)', 80577000.00);
INSERT INTO financial.journal VALUES (116, 'J-2026-09-0116', '2026-09-07', 'commercial.standby_claim', '1', 'Pendapatan standby TRP-2026-0907 (3 jam)', 13500000.00);
INSERT INTO financial.journal VALUES (117, 'J-2026-09-0117', '2026-09-10', 'commercial.bap', 'BAP-2026-0088', 'Pengakuan pendapatan pasir TRP-2026-0910', 82950000.00);
INSERT INTO financial.journal VALUES (118, 'J-2026-09-0118', '2026-09-10', 'buyer.deposit_transaction', '7', 'Pemotongan deposit SC-2026-015 (sebagian — deposit kurang)', 50000000.00);
INSERT INTO financial.journal VALUES (119, 'J-2026-09-0119', '2026-09-10', 'financial.pnbp_charge', '80', 'PNBP per trip TRP-2026-0910 (basis BAP)', 59250000.00);
INSERT INTO financial.journal VALUES (120, 'J-2026-09-0120', '2026-09-10', 'partner.statement_line', '262', 'Hak partner TRP-2026-0910 (basis BAP)', 47400000.00);


--
-- Data for Name: charter_contract; Type: TABLE DATA; Schema: partner; Owner: -
--

INSERT INTO partner.charter_contract VALUES (3, 'CC-2026-003', 'P-SMI', 'SL02', '2026-01-01', '2026-12-31', 'PER_M3', 'PER_TRIP_BAP', '§7.1 GPS/AIS: transponder AIS wajib aktif sepanjang operasi; interval transmisi posisi maks. 5 menit. §7.2 Starlink: koneksi wajib aktif untuk pelaporan real-time (telemetry, BAP digital); gangguan > 24 jam wajib dilaporkan ke dispatcher. §7.3 Sanksi: pelanggaran berulang dikenakan potongan maks. 5% nilai invoice trip terkait.', 'AKTIF', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.charter_contract VALUES (4, 'CC-2026-004', 'P-SMI', 'SL05', '2026-01-01', '2026-12-31', 'PER_M3', 'PER_TRIP_BAP', '§8.1 GPS/AIS: transponder AIS wajib aktif; interval transmisi maks. 5 menit; kehilangan sinyal > 24 jam = pelanggaran. §8.2 Starlink: koneksi wajib aktif untuk telemetry; gangguan > 24 jam wajib dilaporkan. §8.3 Sanksi: potongan maks. 5% nilai invoice trip terkait + hak penghentian charter.', 'AKTIF', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.charter_contract VALUES (5, 'CC-2026-005', 'P-BHL', 'SL09', '2026-01-01', '2026-12-31', 'PER_TRIP', 'PER_TRIP_BAP', '§9.1 GPS/AIS: transponder AIS wajib aktif sepanjang operasi (interval maks. 5 menit). §9.2 Starlink: koneksi wajib aktif; gangguan > 24 jam wajib dilaporkan ke dispatcher. §9.3 Sanksi: potongan maks. 2,5% nilai invoice trip terkait.', 'AKTIF', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.charter_contract VALUES (7, 'CC-2026-007', 'P-MLT', 'M03', '2026-01-01', '2026-12-31', 'TC', 'BULANAN', '§12.1 GPS/AIS: unit TC wajib melapor posisi otomatis via AIS (interval maks. 5 menit). §12.2 Starlink: koneksi wajib aktif untuk laporan harian; gangguan > 24 jam wajib dilaporkan. §12.3 Sanksi: potongan maks. 5% tagihan bulanan TC terkait.', 'AKTIF', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.charter_contract VALUES (8, 'CC-2026-008', 'P-DLM', 'B07', '2026-06-01', '2026-12-31', 'PER_M3', 'PER_TRIP_BAP', '§6.1 GPS/AIS: transponder AIS wajib aktif sepanjang operasi (interval maks. 5 menit). §6.2 Starlink: koneksi wajib aktif untuk telemetry & BAP digital; gangguan > 24 jam wajib dilaporkan. §6.3 Sanksi: potongan maks. 5% nilai invoice trip terkait.', 'AKTIF', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: cost_entry; Type: TABLE DATA; Schema: financial; Owner: -
--

INSERT INTO financial.cost_entry VALUES (2, 903, 'CHARTER', 5, 38000000.00, 'AUTO', 'Hak partner PER_TRIP (FR-06-03)', 104, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO financial.cost_entry VALUES (4, 907, 'STANDBY', NULL, 13500000.00, 'AUTO', 'Standby 3 jam × Rp 4,5 jt (R11)', 116, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO financial.cost_entry VALUES (1, 899, 'CHARTER', 4, 63000000.00, 'AUTO', 'Hak partner basis BAP (FR-06-03)', 98, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO financial.cost_entry VALUES (3, 907, 'CHARTER', 3, 64461600.00, 'AUTO', 'Hak partner basis BAP (FR-06-03)', 114, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO financial.cost_entry VALUES (5, 910, 'CHARTER', 4, 47400000.00, 'AUTO', 'Hak partner basis BAP — deposit buyer kurang, hak TETAP penuh (FR-06-03)', 120, NULL, '2026-09-11 04:37:38.491768+00', '2026-09-11 04:37:38.491768+00');


--
-- Data for Name: invoice; Type: TABLE DATA; Schema: financial; Owner: -
--

INSERT INTO financial.invoice VALUES (231, 'INV-AR-2026-0231', 'SALES', NULL, 115493700.00, 'IDR', 'PAID', '2026-09-07', '2026-10-07', 'B-PRN');
INSERT INTO financial.invoice VALUES (232, 'INV-AR-2026-0232', 'SALES', NULL, 13500000.00, 'IDR', 'ISSUED', '2026-09-07', '2026-10-07', 'B-PRN');
INSERT INTO financial.invoice VALUES (233, 'INV-AR-2026-0233', 'SALES', NULL, 32950000.00, 'IDR', 'ISSUED', '2026-09-10', '2026-10-10', 'B-PSR');


--
-- Data for Name: journal_line; Type: TABLE DATA; Schema: financial; Owner: -
--

INSERT INTO financial.journal_line VALUES (1, 98, 1, '5-5100', 'Beban Charter Kapal', 63000000.00, 0.00);
INSERT INTO financial.journal_line VALUES (2, 98, 2, '2-2200', 'Utang Partner — PT Samudra Mitra', 0.00, 63000000.00);
INSERT INTO financial.journal_line VALUES (3, 104, 1, '5-5100', 'Beban Charter Kapal', 38000000.00, 0.00);
INSERT INTO financial.journal_line VALUES (4, 104, 2, '2-2200', 'Utang Partner — PT Bahari Lines', 0.00, 38000000.00);
INSERT INTO financial.journal_line VALUES (5, 112, 1, '1-1200', 'Piutang Usaha — PT PRN', 115493700.00, 0.00);
INSERT INTO financial.journal_line VALUES (6, 112, 2, '4-4000', 'Pendapatan Penjualan Pasir', 0.00, 115493700.00);
INSERT INTO financial.journal_line VALUES (7, 113, 1, '2-2100', 'Deposit Customer — SC-2026-014', 115493700.00, 0.00);
INSERT INTO financial.journal_line VALUES (8, 113, 2, '1-1200', 'Piutang Usaha — PT PRN', 0.00, 115493700.00);
INSERT INTO financial.journal_line VALUES (9, 114, 1, '5-5100', 'Beban Charter Kapal', 64461600.00, 0.00);
INSERT INTO financial.journal_line VALUES (10, 114, 2, '2-2200', 'Utang Partner — PT Samudra Mitra', 0.00, 64461600.00);
INSERT INTO financial.journal_line VALUES (11, 115, 1, '5-5200', 'Beban PNBP', 80577000.00, 0.00);
INSERT INTO financial.journal_line VALUES (12, 115, 2, '2-2300', 'Utang PNBP', 0.00, 80577000.00);
INSERT INTO financial.journal_line VALUES (13, 116, 1, '1-1200', 'Piutang Usaha (standby) — PT PRN', 13500000.00, 0.00);
INSERT INTO financial.journal_line VALUES (14, 116, 2, '4-4100', 'Pendapatan Standby', 0.00, 13500000.00);
INSERT INTO financial.journal_line VALUES (15, 117, 1, '1-1200', 'Piutang Usaha — PT PSR', 82950000.00, 0.00);
INSERT INTO financial.journal_line VALUES (16, 117, 2, '4-4000', 'Pendapatan Penjualan Pasir', 0.00, 82950000.00);
INSERT INTO financial.journal_line VALUES (17, 118, 1, '2-2100', 'Utang Bongkar & Deposit Diterima Dimuka — PT PSR', 50000000.00, 0.00);
INSERT INTO financial.journal_line VALUES (18, 118, 2, '1-1200', 'Piutang Usaha — PT PSR', 0.00, 50000000.00);
INSERT INTO financial.journal_line VALUES (19, 119, 1, '5-5200', 'Beban PNBP', 59250000.00, 0.00);
INSERT INTO financial.journal_line VALUES (20, 119, 2, '2-2300', 'Utang PNBP', 0.00, 59250000.00);
INSERT INTO financial.journal_line VALUES (21, 120, 1, '5-5100', 'Beban Charter Kapal', 47400000.00, 0.00);
INSERT INTO financial.journal_line VALUES (22, 120, 2, '2-2200', 'Utang Partner — PT Samudra Mitra', 0.00, 47400000.00);


--
-- Data for Name: pnbp_charge; Type: TABLE DATA; Schema: financial; Owner: -
--

INSERT INTO financial.pnbp_charge VALUES (77, 899, 85, 5250.000, 15000.0000, 78750000.00, '2026-09', 'PAID', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO financial.pnbp_charge VALUES (78, 903, 86, 4982.558, 15000.0000, 74738370.00, '2026-09', 'REPORTED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO financial.pnbp_charge VALUES (79, 907, 87, 5371.800, 15000.0000, 80577000.00, '2026-09', 'ACCRUED', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO financial.pnbp_charge VALUES (80, 910, 88, 3950.000, 15000.0000, 59250000.00, '2026-09', 'REPORTED', NULL, '2026-09-11 04:37:38.488597+00', '2026-09-11 04:37:38.488597+00');


--
-- Data for Name: pnbp_tahap_awal; Type: TABLE DATA; Schema: financial; Owner: -
--

INSERT INTO financial.pnbp_tahap_awal VALUES (1, 1, 300000, 27900, 8370000000, 418500000, '2026-08-12', 'PAID', '2026-08-11 09:00:00+00', '2026-09-11 04:37:38.922491+00');
INSERT INTO financial.pnbp_tahap_awal VALUES (2, 90, 400000, 65100, 26040000000, 1302000000, '2026-09-12', 'DUE', NULL, '2026-09-11 04:37:38.923068+00');


--
-- Data for Name: pnbp_tarif; Type: TABLE DATA; Schema: financial; Owner: -
--

INSERT INTO financial.pnbp_tarif VALUES (1, 'DOMESTIK', 93000, 30, 'PP 85/2021 · HPP Kepmen KP 6/2024 · pemanfaatan dalam negeri (PP 26/2023)', '2024-02-28', true, '2026-09-11 04:37:38.906467+00');
INSERT INTO financial.pnbp_tarif VALUES (2, 'EKSPOR', 186000, 35, 'PP 85/2021 · HPP Kepmen KP 6/2024 · pemanfaatan luar negeri (PP 26/2023)', '2024-02-28', true, '2026-09-11 04:37:38.906467+00');
INSERT INTO financial.pnbp_tarif VALUES (3, 'LEGACY', 50000, 30, 'tarif simulasi awal v0.12 — sudah digantikan PP 26/2023', '2026-01-01', false, '2026-09-11 04:37:38.906467+00');


--
-- Data for Name: capa; Type: TABLE DATA; Schema: hse; Owner: -
--

INSERT INTO hse.capa VALUES (1, 'CAPA-2026-009', 'INCIDENT', 'INS-2026-001', 'Ganti seal hidrolik + sediakan drip tray cadangan di M03', 3, '2026-06-20', 'CLOSED', '2026-06-18', NULL, '2026-09-11 04:37:38.683341+00', '2026-09-11 04:37:38.683341+00');
INSERT INTO hse.capa VALUES (2, 'CAPA-2026-011', 'INSPECTION', 'INSP-2609-007', 'APD bertingkat di TB Bahari 07 — ganti harness & sepatu safety', 4, '2026-09-15', 'OPEN', NULL, NULL, '2026-09-11 04:37:38.683341+00', '2026-09-11 04:37:38.683341+00');
INSERT INTO hse.capa VALUES (3, 'CAPA-2026-012', 'INSPECTION', 'INSP-2609-009', 'Guardrail deck LI02 berkarat — ganti 2 segmen', 3, '2026-09-30', 'OPEN', NULL, NULL, '2026-09-11 04:37:38.683341+00', '2026-09-11 04:37:38.683341+00');


--
-- Data for Name: certificate; Type: TABLE DATA; Schema: hse; Owner: -
--

INSERT INTO hse.certificate VALUES (1, 'SL07', 'Sertifikat Keselamatan (SLC)', '2024-01-15', '2026-11-05', NULL, '2026-09-11 04:37:38.680345+00', '2026-09-11 04:37:38.680345+00');
INSERT INTO hse.certificate VALUES (2, 'SL05', 'Sertifikat Keselamatan (SLC)', '2024-01-15', '2027-01-14', NULL, '2026-09-11 04:37:38.680345+00', '2026-09-11 04:37:38.680345+00');
INSERT INTO hse.certificate VALUES (3, 'SL09', 'Sertifikat Keselamatan (SLC)', '2024-01-15', '2027-01-14', NULL, '2026-09-11 04:37:38.680345+00', '2026-09-11 04:37:38.680345+00');
INSERT INTO hse.certificate VALUES (4, 'SL02', 'Sertifikat Keselamatan (SLC)', '2024-01-15', '2027-01-14', NULL, '2026-09-11 04:37:38.680345+00', '2026-09-11 04:37:38.680345+00');
INSERT INTO hse.certificate VALUES (5, 'B07', 'Sertifikat Keselamatan (SLC)', '2024-01-15', '2027-01-14', NULL, '2026-09-11 04:37:38.680345+00', '2026-09-11 04:37:38.680345+00');
INSERT INTO hse.certificate VALUES (6, 'M03', 'Sertifikat Keselamatan (SLC)', '2024-01-15', '2027-01-14', NULL, '2026-09-11 04:37:38.680345+00', '2026-09-11 04:37:38.680345+00');
INSERT INTO hse.certificate VALUES (7, 'LI02', 'Sertifikat Keselamatan (SLC)', '2024-01-15', '2027-01-14', NULL, '2026-09-11 04:37:38.680345+00', '2026-09-11 04:37:38.680345+00');
INSERT INTO hse.certificate VALUES (8, 'B12', 'Sertifikat Keselamatan (SLC)', '2024-01-15', '2027-01-14', NULL, '2026-09-11 04:37:38.680345+00', '2026-09-11 04:37:38.680345+00');
INSERT INTO hse.certificate VALUES (9, 'SL07', 'Sertifikat Alat Apung (Liferaft)', '2024-02-20', '2027-02-19', NULL, '2026-09-11 04:37:38.681386+00', '2026-09-11 04:37:38.681386+00');
INSERT INTO hse.certificate VALUES (10, 'SL09', 'Sertifikat Alat Apung (Liferaft)', '2024-02-20', '2027-02-19', NULL, '2026-09-11 04:37:38.681386+00', '2026-09-11 04:37:38.681386+00');
INSERT INTO hse.certificate VALUES (11, 'LI02', 'Sertifikat Alat Apung (Liferaft)', '2024-02-20', '2026-10-28', NULL, '2026-09-11 04:37:38.681386+00', '2026-09-11 04:37:38.681386+00');
INSERT INTO hse.certificate VALUES (12, 'M03', 'Sertifikat Alat Apung (Liferaft)', '2024-02-20', '2027-02-19', NULL, '2026-09-11 04:37:38.681386+00', '2026-09-11 04:37:38.681386+00');
INSERT INTO hse.certificate VALUES (13, 'B07', 'Sertifikat Alat Apung (Liferaft)', '2024-02-20', '2027-02-19', NULL, '2026-09-11 04:37:38.681386+00', '2026-09-11 04:37:38.681386+00');
INSERT INTO hse.certificate VALUES (14, 'SL02', 'Sertifikat Alat Apung (Liferaft)', '2024-02-20', '2027-02-19', NULL, '2026-09-11 04:37:38.681386+00', '2026-09-11 04:37:38.681386+00');
INSERT INTO hse.certificate VALUES (15, 'SL05', 'Sertifikat Alat Apung (Liferaft)', '2024-02-20', '2027-02-19', NULL, '2026-09-11 04:37:38.681386+00', '2026-09-11 04:37:38.681386+00');
INSERT INTO hse.certificate VALUES (16, 'B12', 'Sertifikat Alat Apung (Liferaft)', '2024-02-20', '2027-02-19', NULL, '2026-09-11 04:37:38.681386+00', '2026-09-11 04:37:38.681386+00');


--
-- Data for Name: incident; Type: TABLE DATA; Schema: hse; Owner: -
--

INSERT INTO hse.incident VALUES (2, 'INS-2026-001', '2026-06-03 01:15:00+00', 'M03', 'NEAR_MISS', 'Spill hidrolik kecil di ruang mesin — tertahan drip tray, laporan lengkap dibuat', 'PWA', 'CLOSED', '2026-06-10 03:00:00+00', NULL, '2026-09-11 04:37:38.678545+00', '2026-09-11 04:37:38.678545+00', NULL, NULL);
INSERT INTO hse.incident VALUES (3, 'INS-2026-002', '2026-07-12 07:05:00+00', 'B07', 'FIRST_AID', 'Kru tersandung rak di deck saat bongkar — istirahat 1 hari', 'PWA', 'CLOSED', '2026-07-15 02:00:00+00', NULL, '2026-09-11 04:37:38.678545+00', '2026-09-11 04:37:38.678545+00', NULL, NULL);
INSERT INTO hse.incident VALUES (4, 'INS-2026-003', '2026-08-02 23:40:00+00', 'SL05', 'NEAR_MISS', 'Tali tambat kendor saat sandar — ditangani awak, tanpa kerusakan', 'PWA', 'CLOSED', '2026-08-05 01:30:00+00', NULL, '2026-09-11 04:37:38.678545+00', '2026-09-11 04:37:38.678545+00', NULL, NULL);
INSERT INTO hse.incident VALUES (1, 'INS-2024-001', '2024-05-17 02:30:00+00', 'LI02', 'LTI', 'Jari kru terjepit konveyor saat bongkar — cuti kerja 12 hari', 'PWA', 'CLOSED', '2024-06-15 09:00:00+00', NULL, '2026-09-11 04:37:38.678545+00', '2026-09-11 04:37:38.678545+00', NULL, NULL);


--
-- Data for Name: induction; Type: TABLE DATA; Schema: hse; Owner: -
--

INSERT INTO hse.induction VALUES (1, 'Dedi Kurniawan', 'Able Seaman', 'LI02', '2026-09-01', NULL, '2026-09-11 04:37:38.682626+00', '2026-09-11 04:37:38.682626+00');
INSERT INTO hse.induction VALUES (2, 'Andi Saputra', 'Deck Rating', 'SL09', '2026-08-20', NULL, '2026-09-11 04:37:38.682626+00', '2026-09-11 04:37:38.682626+00');
INSERT INTO hse.induction VALUES (3, 'Fajar Ramadhan', 'Oiler', 'SL07', '2026-09-04', NULL, '2026-09-11 04:37:38.682626+00', '2026-09-11 04:37:38.682626+00');
INSERT INTO hse.induction VALUES (4, 'Budi Hartono', 'Oiler', 'B12', '2026-08-22', NULL, '2026-09-11 04:37:38.682626+00', '2026-09-11 04:37:38.682626+00');
INSERT INTO hse.induction VALUES (5, 'Eko Prasetyo', 'Deck Rating', 'SL02', '2026-09-02', NULL, '2026-09-11 04:37:38.682626+00', '2026-09-11 04:37:38.682626+00');
INSERT INTO hse.induction VALUES (6, 'Citra Lestari', 'Cook', 'M03', '2026-08-25', NULL, '2026-09-11 04:37:38.682626+00', '2026-09-11 04:37:38.682626+00');


--
-- Data for Name: inspection; Type: TABLE DATA; Schema: hse; Owner: -
--

INSERT INTO hse.inspection VALUES (1, 'INSP-2609-001', '2026-09-01', 'SL02', 'APD', 'DONE', 'COMPLIANT', 0, 'H. Rudi', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (2, 'INSP-2609-002', '2026-09-01', 'SL05', 'APD', 'DONE', 'COMPLIANT', 0, 'H. Rudi', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (3, 'INSP-2609-003', '2026-09-02', 'SL07', 'ALAT_APUNG', 'DONE', 'COMPLIANT', 0, 'Timo', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (4, 'INSP-2609-004', '2026-09-02', 'SL09', 'ALAT_APUNG', 'DONE', 'COMPLIANT', 0, 'Timo', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (5, 'INSP-2609-005', '2026-09-03', 'B07', 'DECK', 'DONE', 'FINDING', 1, 'H. Rudi', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (6, 'INSP-2609-006', '2026-09-03', 'B12', 'DECK', 'DONE', 'COMPLIANT', 0, 'H. Rudi', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (7, 'INSP-2609-007', '2026-09-04', 'B07', 'APD', 'DONE', 'FINDING', 1, 'Sari', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (8, 'INSP-2609-008', '2026-09-04', 'SITE-G', 'HOUSEKEEPING', 'DONE', 'COMPLIANT', 0, 'Sari', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (9, 'INSP-2609-009', '2026-09-05', 'LI02', 'DECK', 'DONE', 'FINDING', 1, 'Timo', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (10, 'INSP-2609-010', '2026-09-05', 'M03', 'RUMAH_MESIN', 'DONE', 'COMPLIANT', 0, 'Timo', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (11, 'INSP-2609-011', '2026-09-06', 'B07', 'ALAT_APUNG', 'DONE', 'COMPLIANT', 0, 'Sari', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (12, 'INSP-2609-012', '2026-09-06', 'SL05', 'DECK', 'DONE', 'COMPLIANT', 0, 'Sari', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (13, 'INSP-2609-013', '2026-09-07', 'SL02', 'RUMAH_MESIN', 'DONE', 'COMPLIANT', 0, 'H. Rudi', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (14, 'INSP-2609-014', '2026-09-07', 'LI02', 'APD', 'DONE', 'COMPLIANT', 0, 'H. Rudi', NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (15, 'INSP-2609-015', '2026-09-09', 'SL07', 'APD', 'SCHEDULED', NULL, 0, NULL, NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (16, 'INSP-2609-016', '2026-09-10', 'B12', 'ALAT_APUNG', 'SCHEDULED', NULL, 0, NULL, NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (17, 'INSP-2609-017', '2026-09-11', 'SL09', 'DECK', 'SCHEDULED', NULL, 0, NULL, NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (18, 'INSP-2609-018', '2026-09-15', 'B07', 'RUMAH_MESIN', 'SCHEDULED', NULL, 0, NULL, NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (19, 'INSP-2609-019', '2026-09-17', 'M03', 'APD', 'SCHEDULED', NULL, 0, NULL, NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');
INSERT INTO hse.inspection VALUES (20, 'INSP-2609-020', '2026-09-19', 'SL02', 'ALAT_APUNG', 'SCHEDULED', NULL, 0, NULL, NULL, '2026-09-11 04:37:38.679554+00', '2026-09-11 04:37:38.679554+00');


--
-- Data for Name: toolbox_meeting; Type: TABLE DATA; Schema: hse; Owner: -
--

INSERT INTO hse.toolbox_meeting VALUES (1, 'SL07', '2026-08-24', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (2, 'SL07', '2026-08-31', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (3, 'SL07', '2026-09-07', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (4, 'SL09', '2026-08-24', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (5, 'SL09', '2026-08-31', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (6, 'SL09', '2026-09-07', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (7, 'LI02', '2026-08-24', true, 8, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (8, 'LI02', '2026-08-31', true, 8, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (9, 'LI02', '2026-09-07', true, 8, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (10, 'M03', '2026-08-24', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (11, 'M03', '2026-08-31', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (12, 'M03', '2026-09-07', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (13, 'B07', '2026-08-24', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (14, 'B07', '2026-08-31', false, NULL, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (15, 'B07', '2026-09-07', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (16, 'SL02', '2026-08-24', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (17, 'SL02', '2026-08-31', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (18, 'SL02', '2026-09-07', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (19, 'SL05', '2026-08-24', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (20, 'SL05', '2026-08-31', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (21, 'SL05', '2026-09-07', false, NULL, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (22, 'B12', '2026-08-24', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (23, 'B12', '2026-08-31', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');
INSERT INTO hse.toolbox_meeting VALUES (24, 'B12', '2026-09-07', true, 9, NULL, '2026-09-11 04:37:38.681888+00', '2026-09-11 04:37:38.681888+00');


--
-- Data for Name: report_schedule; Type: TABLE DATA; Schema: notification; Owner: -
--

INSERT INTO notification.report_schedule VALUES (1, 'produksi-bap', 'ops@pasirlaut.co.id, keu@pasirlaut.co.id', 'DAILY', 7, true, '2026-09-11 04:37:39.116544+00', 'seed', '2026-09-11 04:37:39.108027+00');


--
-- Data for Name: email_outbox; Type: TABLE DATA; Schema: notification; Owner: -
--

INSERT INTO notification.email_outbox VALUES (1, 1, 'produksi-bap', 'RPT/PRODUKSIBAP/20260911/001', 'ops@pasirlaut.co.id, keu@pasirlaut.co.id', '[ERP Pasir Laut] produksi-bap — RPT/PRODUKSIBAP/20260911/001', '/demo/laporan-produksi-bap.pdf', 'SENT', 'uat-21 simulasi kirim', '2026-09-11 04:37:39.116544+00', NULL);
INSERT INTO notification.email_outbox VALUES (2, 1, 'produksi-bap', 'RPT/PRODUKSIBAP/20260911/002', 'ops@pasirlaut.co.id, keu@pasirlaut.co.id', '[ERP Pasir Laut] #2', '/demo/2.pdf', 'SENT', 'uat-21 simulasi kirim', '2026-09-11 04:37:39.118637+00', NULL);
INSERT INTO notification.email_outbox VALUES (3, NULL, 'pnbp', 'RPT/PNBP/20260909/099', 'keu@pasirlaut.co.id', 'manual', NULL, 'SENT', 'uat-21 kirim manual', '2026-09-11 04:37:39.119816+00', NULL);


--
-- Data for Name: rule; Type: TABLE DATA; Schema: notification; Owner: -
--

INSERT INTO notification.rule VALUES (1, 'EWS_EXCEEDED', 'tpl_ews_exceeded', '{"email": ["env@ppteluk.co.id"], "telegram": ["ops-dispatch", "nakhoda-kapal"]}', '{"level2_after_h": "2", "level3_after_h": "6"}', true, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO notification.rule VALUES (2, 'BAP_SIGNED', 'tpl_bap_signed', '{"email": ["buyer-pic", "partner-pic"], "telegram": ["ops-dispatch"]}', NULL, true, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO notification.rule VALUES (3, 'DEPOSIT_LOW', 'tpl_deposit_low', '{"email": ["finance", "buyer-pic"]}', NULL, true, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO notification.rule VALUES (4, 'GEOFENCE_EXIT', 'tpl_geofence_exit', '{"email": ["ops@ppteluk.co.id"], "telegram": ["ops-dispatch", "kapten-b12"]}', '{"level2_after_h": "1"}', true, '2026-09-11 04:37:38.859555+00', '2026-09-11 04:37:38.859555+00');
INSERT INTO notification.rule VALUES (5, 'PNBP_TAHAP_AWAL', 'tpl_pnbp_tahap_awal', '{"email": ["finance@ppteluk.co.id", "cfo@ppteluk.co.id"], "telegram": ["keu-pnbp"]}', '{"batal_izin": "tidak dibayar setelah due_date — persetujuan izin batal (Permen KP 41/2023)"}', true, '2026-09-11 04:37:38.924967+00', '2026-09-11 04:37:38.924967+00');
INSERT INTO notification.rule VALUES (6, 'AIS_SIGNAL_LOST', 'tpl_ais_lost', '{"email": ["ops@ppteluk.co.id", "ops@baharilines.co.id"], "telegram": ["ops-dispatch"]}', '{"sanksi": "gap > 24 jam = pelanggaran §9.1 — potongan invoice trip"}', true, '2026-09-11 04:37:38.964338+00', '2026-09-11 04:37:38.964338+00');
INSERT INTO notification.rule VALUES (7, 'STARLINK_OFFLINE', 'tpl_starlink_down', '{"email": ["ops@ppteluk.co.id", "ops@samudramitra.co.id"], "telegram": ["ops-dispatch"]}', '{"sanksi": "offline > 24 jam = pelanggaran §8.2 — potongan maks 5%"}', true, '2026-09-11 04:37:38.964338+00', '2026-09-11 04:37:38.964338+00');


--
-- Data for Name: log; Type: TABLE DATA; Schema: notification; Owner: -
--

INSERT INTO notification.log VALUES (1, 2, 'EMAIL', 'rahmat@prn.co.id', '{"bap_no": "BAP-2026-0087", "volume_m3": 5371.80}', 'SENT', '2026-09-07 07:36:00+00', '2026-09-07 07:36:00+00');
INSERT INTO notification.log VALUES (2, 2, 'EMAIL', 'ops@samudramitra.co.id', '{"bap_no": "BAP-2026-0087", "hak_partner": 64461600}', 'SENT', '2026-09-07 07:36:00+00', '2026-09-07 07:36:00+00');
INSERT INTO notification.log VALUES (3, 1, 'TELEGRAM', 'ops-dispatch', '{"value": 128, "station": "ST-03", "parameter": "TURBIDITY"}', 'SENT', '2026-09-06 23:05:00+00', '2026-09-06 23:05:00+00');
INSERT INTO notification.log VALUES (4, 1, 'TELEGRAM', 'nakhoda:SL02', '{"via": "starlink", "value": 128, "station": "ST-03", "parameter": "TURBIDITY"}', 'SENT', '2026-09-06 23:05:00+00', '2026-09-06 23:05:00+00');
INSERT INTO notification.log VALUES (5, 4, 'TELEGRAM', 'ops-dispatch', '{"zona": "Zona Dok Marina Jaya (DOK)", "event": "EXIT", "fleet": "B12", "waktu": "07 Sep 14:35 WIB", "posisi": "106.20, -5.925", "catatan": "kapal fase DOK terdeteksi di luar zona dok — cek tindak lanjut"}', 'SENT', '2026-09-07 07:36:00+00', '2026-09-11 04:37:38.859888+00');
INSERT INTO notification.log VALUES (6, 4, 'EMAIL', 'ops@ppteluk.co.id', '{"zona": "Zona Dok Marina Jaya (DOK)", "event": "EXIT", "fleet": "B12", "waktu": "07 Sep 14:35 WIB", "posisi": "106.20, -5.925", "catatan": "kapal fase DOK terdeteksi di luar zona dok — cek tindak lanjut"}', 'SENT', '2026-09-07 07:36:00+00', '2026-09-11 04:37:38.859888+00');
INSERT INTO notification.log VALUES (7, 5, 'TELEGRAM', 'keu-pnbp', '{"buyer": "Pan Jurong Reclamation Pte Ltd", "catatan": "bayar ≤7 hari sejak tagihan — izin batal bila lewat (Permen KP 41/2023)", "kontrak": "SC-2026-X01", "jatuh_tempo": "12 Sep 2026", "tagihan_tahap_awal": 1302000000}', 'SENT', '2026-09-09 01:00:00+00', '2026-09-11 04:37:38.925252+00');
INSERT INTO notification.log VALUES (8, 5, 'EMAIL', 'finance@ppteluk.co.id', '{"buyer": "Pan Jurong Reclamation Pte Ltd", "catatan": "bayar ≤7 hari sejak tagihan — izin batal bila lewat (Permen KP 41/2023)", "kontrak": "SC-2026-X01", "jatuh_tempo": "12 Sep 2026", "tagihan_tahap_awal": 1302000000}', 'SENT', '2026-09-09 01:00:00+00', '2026-09-11 04:37:38.925252+00');
INSERT INTO notification.log VALUES (9, 6, 'EMAIL', 'ops@ppteluk.co.id', '{"kapal": "SL09", "catatan": "laporan gangguan sinyal ke dispatcher", "gap_jam": 26, "klausul": "§9.1 CC-2026-005", "partner": "PT Bahari Lines"}', 'SENT', '2026-09-11 02:37:38.964839+00', '2026-09-11 04:37:38.964839+00');
INSERT INTO notification.log VALUES (10, 6, 'TELEGRAM', 'ops-dispatch', '{"kapal": "SL09", "catatan": "transponder AIS tidak terdeteksi 26 jam — cek unit", "gap_jam": 26, "klausul": "§9.1 CC-2026-005", "partner": "PT Bahari Lines"}', 'SENT', '2026-09-11 02:37:38.964839+00', '2026-09-11 04:37:38.964839+00');
INSERT INTO notification.log VALUES (11, 7, 'EMAIL', 'ops@samudramitra.co.id', '{"kapal": "SL05", "catatan": "mohon perbaikan terminal; sanksi potongan maks 5%", "klausul": "§8.2 CC-2026-004", "partner": "PT Samudra Mitra", "offline_jam": 72}', 'SENT', '2026-09-11 02:37:38.964839+00', '2026-09-11 04:37:38.964839+00');
INSERT INTO notification.log VALUES (12, 7, 'TELEGRAM', 'ops-dispatch', '{"kapal": "SL05", "catatan": "Starlink offline 3 hari — BAP digital tertunda", "klausul": "§8.2 CC-2026-004", "partner": "PT Samudra Mitra", "offline_jam": 72}', 'SENT', '2026-09-11 02:37:38.964839+00', '2026-09-11 04:37:38.964839+00');


--
-- Data for Name: discharge_event; Type: TABLE DATA; Schema: operational; Owner: -
--

INSERT INTO operational.discharge_event VALUES ('9a000000-0000-0000-0000-000000000921', 907, 'START', '2026-09-07 02:30:00+00', NULL, 'mulai bongkar setelah slot site siap', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO operational.discharge_event VALUES ('9a000000-0000-0000-0000-000000000922', 907, 'STOP', '2026-09-07 03:45:00+00', 'CUACA', 'hujan singkat — jarak pandang', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO operational.discharge_event VALUES ('9a000000-0000-0000-0000-000000000923', 907, 'RESUME', '2026-09-07 04:10:00+00', NULL, NULL, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO operational.discharge_event VALUES ('9a000000-0000-0000-0000-000000000924', 907, 'COMPLETE', '2026-09-07 06:00:00+00', NULL, 'bongkar tuntas — sisa di hopper dicek survey akhir', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: manual_report; Type: TABLE DATA; Schema: operational; Owner: -
--

INSERT INTO operational.manual_report VALUES ('9a000000-0000-0000-0000-000000000931', 907, 'FUEL_STATUS', '2026-09-06 22:00:00+00', 'H. Bakti', '{"note": "cukup untuk 2 siklus", "fuel_level_pct": 62}', '2026-09-06 22:02:00+00', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: nor; Type: TABLE DATA; Schema: operational; Owner: -
--

INSERT INTO operational.nor VALUES ('9a000000-0000-0000-0000-000000000907', 907, 'H. Bakti (Nakhoda MV Sinar Laut 02)', '2026-09-06 11:30:00+00', NULL, '2026-09-11 04:37:38.232279+00');
INSERT INTO operational.nor VALUES ('9a000000-0000-0000-0000-000000000910', 910, 'H. Andi (Nakhoda MV Sinar Laut 05)', '2026-09-09 13:00:00+00', NULL, '2026-09-11 04:37:38.480484+00');


--
-- Data for Name: schedule_plan; Type: TABLE DATA; Schema: operational; Owner: -
--

INSERT INTO operational.schedule_plan VALUES (1, 1, '2026-07-19 05:00:00+00', '2026-07-19 11:30:00+00', 0.00, 'APPROVED', true, 'uat-approval', '2026-09-11 04:37:39.064734+00', NULL, 'AP-04', '2026-09-11 04:37:39.064734+00');
INSERT INTO operational.schedule_plan VALUES (2, 2, '2026-07-20 15:00:00+00', '2026-07-20 21:30:00+00', 0.00, 'APPROVED', true, 'uat-approval', '2026-09-11 04:37:39.064734+00', NULL, 'AP-04', '2026-09-11 04:37:39.064734+00');
INSERT INTO operational.schedule_plan VALUES (3, 3, '2026-07-21 20:00:00+00', '2026-07-22 03:00:00+00', 0.00, 'APPROVED', true, 'uat-approval', '2026-09-11 04:37:39.064734+00', NULL, 'AP-04', '2026-09-11 04:37:39.064734+00');
INSERT INTO operational.schedule_plan VALUES (4, 4, '2026-07-23 00:00:00+00', '2026-07-23 07:00:00+00', 0.00, 'APPROVED', true, 'uat-approval', '2026-09-11 04:37:39.064734+00', NULL, 'AP-04', '2026-09-11 04:37:39.064734+00');


--
-- Data for Name: schedule_proposal; Type: TABLE DATA; Schema: operational; Owner: -
--

INSERT INTO operational.schedule_proposal VALUES (1, '{"mode": "gantt", "pinned": {}}', 4, 'APPROVED', 'uat-approval', '2026-09-11 04:37:39.063627+00', 'uat-approval', '2026-09-11 04:37:39.064734+00', NULL);
INSERT INTO operational.schedule_proposal VALUES (2, '{"mode": "gantt", "pinned": {}}', 2, 'REJECTED', 'uat-approval', '2026-09-11 04:37:39.06756+00', 'uat-approval', '2026-09-11 04:37:39.06756+00', 'uji tolak');


--
-- Data for Name: site_permit; Type: TABLE DATA; Schema: operational; Owner: -
--

INSERT INTO operational.site_permit VALUES (1, 907, 'SP-SITEG-2026-0907', 'PT Pembangunan Reklamasi Nusantara', '2026-09-05 02:00:00+00', '2026-09-08 16:59:00+00', 'izin memasuki area bongkar site G', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: waiting_log; Type: TABLE DATA; Schema: operational; Owner: -
--

INSERT INTO operational.waiting_log VALUES ('9a000000-0000-0000-0000-000000000911', 907, '2026-09-05 21:30:00+00', '2026-09-06 11:00:00+00', 'PASUT', 'menunggu pasang sore untuk keberangkatan', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO operational.waiting_log VALUES ('9a000000-0000-0000-0000-000000000912', 907, '2026-09-06 19:00:00+00', '2026-09-07 02:30:00+00', 'ANTRIAN_KAPAL', 'slot bongkar site G — 1 kapal di depan', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: param; Owner: -
--

INSERT INTO param.audit_log VALUES (1, 'param.system_parameter', 'ews_warning_pct', 'nilai', '90', '85', 'uat-rbac', '2026-09-11 04:37:39.012586+00');
INSERT INTO param.audit_log VALUES (2, 'param.system_parameter', 'ews_warning_pct', 'nilai', '85', '90', 'uat-rbac', '2026-09-11 04:37:39.0144+00');


--
-- Data for Name: status; Type: TABLE DATA; Schema: param; Owner: -
--

INSERT INTO param.status VALUES ('TRIP_STATUS', 'LOADING', 'Sedang muat di blok');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'SURVEY_SETTLING', 'Survey penyelesaian muat');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'DEPARTED', 'Berangkat ke site bongkar');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'ARRIVED', 'Tiba di site (geofence otomatis)');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'SURVEY_DISCHARGE', 'Survey awal bongkar');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'DISCHARGING', 'Bongkar berjalan');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'BAP_RETURN', 'Menunggu / proses BAP');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'INVOICED', 'Tagihan terbit');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'SETTLED', 'Settled (deposit/AR diproses)');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'CLOSED', 'Trip selesai & terkunci');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'CANCELLED', 'Dibatalkan');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'PARTIAL', 'Bongkar parsial (multi-site)');
INSERT INTO param.status VALUES ('TRIP_STATUS', 'CLAIM', 'Klaim / sanggahan');
INSERT INTO param.status VALUES ('BAP_STATUS', 'DRAFT', 'Draft BAP');
INSERT INTO param.status VALUES ('BAP_STATUS', 'SIGNED', 'BAP sah (TTD 3 pihak lengkap)');
INSERT INTO param.status VALUES ('BAP_STATUS', 'DISPUTED', 'Disangkal customer (objection)');
INSERT INTO param.status VALUES ('BAP_STATUS', 'CORRECTED', 'Dikoreksi (dokumen koreksi bernomor)');
INSERT INTO param.status VALUES ('PAYABLE_STATUS', 'WAITING', 'Menunggu pemicu pencairan');
INSERT INTO param.status VALUES ('PAYABLE_STATUS', 'TRIGGERED', 'Terpicu — siap ditagih/dibayar');
INSERT INTO param.status VALUES ('PAYABLE_STATUS', 'PAID', 'Terbayar');


--
-- Data for Name: system_parameter; Type: TABLE DATA; Schema: param; Owner: -
--

INSERT INTO param.system_parameter VALUES ('shrinkage_tol_pct', 'Toleransi shrinkage QA', '2', '%', 'Di atas ambang → flag QA review', '2026-09-11 04:37:39.006193+00', 'seed');
INSERT INTO param.system_parameter VALUES ('free_time_default', 'Free time bongkar default (R12)', '24', 'jam', 'Default; nilai per kontrak dapat berbeda', '2026-09-11 04:37:39.006193+00', 'seed');
INSERT INTO param.system_parameter VALUES ('hs_waspada_bongkar', 'Ambang Hs waspada bongkar di site', '1.0', 'm', 'Kebijakan internal ops (bukan regulasi)', '2026-09-11 04:37:39.006193+00', 'seed');
INSERT INTO param.system_parameter VALUES ('hs_tunda_ops', 'Ambang Hs tunda pengerukan/bongkar', '1.5', 'm', 'Kebijakan internal ops (bukan regulasi)', '2026-09-11 04:37:39.006193+00', 'seed');
INSERT INTO param.system_parameter VALUES ('ews_warning_pct', 'Ambang EWS warning (dari baku mutu)', '90', '%', 'Pemicu warning pemantauan kualitas air', '2026-09-11 04:37:39.0144+00', 'uat-rbac');


--
-- Data for Name: invoice; Type: TABLE DATA; Schema: partner; Owner: -
--

INSERT INTO partner.invoice VALUES (89, 'P-SMI', 4, 'INV-P-2026-089', '2026-09-07', 63000000.00, 'MATCH', NULL, 'finance', '2026-09-07 09:00:00+00', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.invoice VALUES (91, 'P-MLT', 7, 'INV-P-2026-091', '2026-09-07', 869550000.00, 'DIFF', 'TC Sep 2026: klaim +2,3% di atas hitungan sistem (Rp 850.000.000) — klarifikasi dulu, bayar yang cocok (FR-06-04)', NULL, NULL, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.invoice VALUES (92, 'P-BHL', 5, 'INV-P-2026-093', '2026-09-08', 38000000.00, 'MATCH', NULL, 'finance', '2026-09-09 03:00:00+00', NULL, '2026-09-11 04:37:38.492939+00', '2026-09-11 04:37:38.492939+00');


--
-- Data for Name: payment; Type: TABLE DATA; Schema: partner; Owner: -
--

INSERT INTO partner.payment VALUES (1, 'P-SMI', '2026-09-07', 63000000.00, 'TRANSFER', 'finance', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: rate_card; Type: TABLE DATA; Schema: partner; Owner: -
--

INSERT INTO partner.rate_card VALUES (5, 5, NULL, 38000000.00, NULL, '2026-01-01', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.rate_card VALUES (8, 8, 11500.0000, NULL, NULL, '2026-06-01', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.rate_card VALUES (4, 4, 12000.0000, NULL, NULL, '2026-01-01', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.rate_card VALUES (3, 3, 12000.0000, NULL, NULL, '2026-01-01', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.rate_card VALUES (7, 7, NULL, NULL, 850000000.00, '2026-01-01', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');


--
-- Data for Name: statement_line; Type: TABLE DATA; Schema: partner; Owner: -
--

INSERT INTO partner.statement_line VALUES (259, 899, 4, 4, 'PER_M3', 5250.000, 12000.0000, 63000000.00, 'PAID', 'PO_COMPLETED', '2026-09-03 02:00:00+00', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.statement_line VALUES (260, 903, 5, 5, 'PER_TRIP', 4982.558, 38000000.0000, 38000000.00, 'TRIGGERED', 'DEPOSIT_DEDUCTED', '2026-09-04 01:00:00+00', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.statement_line VALUES (261, 907, 3, 3, 'PER_M3', 5371.800, 12000.0000, 64461600.00, 'TRIGGERED', 'DEPOSIT_DEDUCTED', '2026-09-07 07:36:00+00', NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO partner.statement_line VALUES (262, 910, 4, 4, 'PER_M3', 3950.000, 12000.0000, 47400000.00, 'TRIGGERED', 'DEPOSIT_DEDUCTED', '2026-09-09 19:16:00+00', NULL, '2026-09-11 04:37:38.489882+00', '2026-09-11 04:37:38.489882+00');


--
-- Data for Name: payment_allocation; Type: TABLE DATA; Schema: partner; Owner: -
--

INSERT INTO partner.payment_allocation VALUES (1, 1, 259, 63000000.00);


--
-- Data for Name: draft_survey; Type: TABLE DATA; Schema: survey; Owner: -
--

INSERT INTO survey.draft_survey VALUES (1, 899, 'MUAT', 'Budi Santoso', 'PT Surveyor Laut Nusantara', 'SLN-0451', '2026-09-01 07:00:00+00', '{"titik": [{"m": 4.50, "sumber": "DEPAN-KIRI"}, {"m": 4.48, "sumber": "DEPAN-KANAN"}, {"m": 4.52, "sumber": "TENGAH-KIRI"}, {"m": 4.51, "sumber": "TENGAH-KANAN"}, {"m": 4.49, "sumber": "BELAKANG-KIRI"}, {"m": 4.50, "sumber": "BELAKANG-KANAN"}]}', NULL, 1.02460, 2.65000, 13801.250, -15.750, 13785.500, 5250.000, '{"buyer": "Ir. Rahmat", "kapal": "H. Andi"}', '2026-09-01 07:40:00+00', 101, true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO survey.draft_survey VALUES (2, 903, 'MUAT', 'Budi Santoso', 'PT Surveyor Laut Nusantara', 'SLN-0451', '2026-09-03 00:30:00+00', '{"titik": [{"m": 4.41, "sumber": "DEPAN-KIRI"}, {"m": 4.40, "sumber": "DEPAN-KANAN"}, {"m": 4.43, "sumber": "TENGAH-KIRI"}, {"m": 4.42, "sumber": "TENGAH-KANAN"}, {"m": 4.40, "sumber": "BELAKANG-KIRI"}, {"m": 4.41, "sumber": "BELAKANG-KANAN"}]}', NULL, 1.02480, 2.65000, 13154.800, -12.400, 13142.400, 5001.120, '{"buyer": "Ir. Rahmat", "kapal": "Capt. Dedi"}', '2026-09-03 01:10:00+00', 103, true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO survey.draft_survey VALUES (3, 907, 'MUAT', 'Budi Santoso', 'PT Surveyor Laut Nusantara', 'SLN-0451', '2026-09-05 21:00:00+00', '{"titik": [{"m": 4.62, "sumber": "DEPAN-KIRI"}, {"m": 4.61, "sumber": "DEPAN-KANAN"}, {"m": 4.63, "sumber": "TENGAH-KIRI"}, {"m": 4.63, "sumber": "TENGAH-KANAN"}, {"m": 4.60, "sumber": "BELAKANG-KIRI"}, {"m": 4.61, "sumber": "BELAKANG-KANAN"}]}', NULL, 1.02470, 2.65000, 14250.300, -18.400, 14231.900, 5420.500, '{"buyer": "Ir. Rahmat", "kapal": "H. Bakti"}', '2026-09-05 21:45:00+00', 111, true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO survey.draft_survey VALUES (4, 907, 'AWAL_BONGKAR', 'Budi Santoso', 'PT Surveyor Laut Nusantara', 'SLN-0451', '2026-09-06 19:30:00+00', '{"titik": [{"m": 4.59, "sumber": "DEPAN-KIRI"}, {"m": 4.58, "sumber": "DEPAN-KANAN"}, {"m": 4.60, "sumber": "TENGAH-KIRI"}, {"m": 4.60, "sumber": "TENGAH-KANAN"}, {"m": 4.57, "sumber": "BELAKANG-KIRI"}, {"m": 4.58, "sumber": "BELAKANG-KANAN"}]}', NULL, 1.02150, 2.65000, 14190.600, -17.200, 14173.400, 5398.200, '{"buyer": "Ir. Rahmat", "kapal": "H. Bakti"}', '2026-09-06 20:10:00+00', 112, true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO survey.draft_survey VALUES (5, 907, 'AKHIR_BONGKAR', 'Budi Santoso', 'PT Surveyor Laut Nusantara', 'SLN-0451', '2026-09-07 06:20:00+00', '{"titik": [{"m": 3.02, "sumber": "DEPAN-KIRI"}, {"m": 3.01, "sumber": "DEPAN-KANAN"}, {"m": 3.03, "sumber": "TENGAH-KIRI"}, {"m": 3.02, "sumber": "TENGAH-KANAN"}, {"m": 3.00, "sumber": "BELAKANG-KIRI"}, {"m": 3.01, "sumber": "BELAKANG-KANAN"}]}', NULL, 1.02150, 2.65000, 69.500, -0.300, 69.200, 26.400, '{"buyer": "Ir. Rahmat", "kapal": "H. Bakti"}', '2026-09-07 06:45:00+00', 113, true, NULL, '2026-09-11 04:37:38.232279+00', '2026-09-11 04:37:38.232279+00');
INSERT INTO survey.draft_survey VALUES (6, 910, 'MUAT', 'Budi Santoso', 'PT Surveyor Laut Nusantara', 'SLN-0451', '2026-09-08 02:00:00+00', '{"titik": [{"m": 4.44, "sumber": "DEPAN-KIRI"}, {"m": 4.43, "sumber": "DEPAN-KANAN"}, {"m": 4.45, "sumber": "TENGAH-KIRI"}, {"m": 4.44, "sumber": "TENGAH-KANAN"}, {"m": 4.42, "sumber": "BELAKANG-KIRI"}, {"m": 4.43, "sumber": "BELAKANG-KANAN"}]}', NULL, 1.02470, 2.65000, 10498.600, -11.200, 10487.400, 4000.000, '{"buyer": "Ir. Sinta Wijaya", "kapal": "H. Andi"}', '2026-09-08 02:40:00+00', NULL, true, NULL, '2026-09-11 04:37:38.479597+00', '2026-09-11 04:37:38.479597+00');
INSERT INTO survey.draft_survey VALUES (7, 910, 'AWAL_BONGKAR', 'Budi Santoso', 'PT Surveyor Laut Nusantara', 'SLN-0451', '2026-09-09 13:30:00+00', '{"titik": [{"m": 3.52, "sumber": "DEPAN-KIRI"}, {"m": 3.51, "sumber": "DEPAN-KANAN"}, {"m": 3.53, "sumber": "TENGAH-KIRI"}, {"m": 3.52, "sumber": "TENGAH-KANAN"}, {"m": 3.50, "sumber": "BELAKANG-KIRI"}, {"m": 3.51, "sumber": "BELAKANG-KANAN"}]}', NULL, 1.02500, 2.65000, 10421.300, -9.900, 10411.400, 3970.000, '{"buyer": "Ir. Sinta Wijaya", "kapal": "H. Andi"}', '2026-09-09 14:10:00+00', NULL, true, NULL, '2026-09-11 04:37:38.479597+00', '2026-09-11 04:37:38.479597+00');
INSERT INTO survey.draft_survey VALUES (8, 910, 'AKHIR_BONGKAR', 'Budi Santoso', 'PT Surveyor Laut Nusantara', 'SLN-0451', '2026-09-09 18:30:00+00', '{"titik": [{"m": 0.10, "sumber": "DEPAN-KIRI"}, {"m": 0.09, "sumber": "DEPAN-KANAN"}, {"m": 0.11, "sumber": "TENGAH-KIRI"}, {"m": 0.10, "sumber": "TENGAH-KANAN"}, {"m": 0.08, "sumber": "BELAKANG-KIRI"}, {"m": 0.09, "sumber": "BELAKANG-KANAN"}]}', NULL, 1.02500, 2.65000, 52.700, -0.500, 52.200, 20.000, '{"buyer": "Ir. Sinta Wijaya", "kapal": "H. Andi"}', '2026-09-09 18:50:00+00', NULL, true, NULL, '2026-09-11 04:37:38.479597+00', '2026-09-11 04:37:38.479597+00');


--
-- Data for Name: ais_position; Type: TABLE DATA; Schema: telemetry; Owner: -
--

INSERT INTO telemetry.ais_position VALUES (2, 'SL05', NULL, -5.73, 106.16, 9.60, 94.0, '2026-09-07 07:30:00+00');
INSERT INTO telemetry.ais_position VALUES (1, 'SL02', NULL, -5.97, 106.36, 0.00, 0.0, '2026-09-07 07:30:00+00');
INSERT INTO telemetry.ais_position VALUES (3, 'B12', NULL, -5.925, 106.2, 0.00, 0.0, '2026-09-07 07:30:00+00');
INSERT INTO telemetry.ais_position VALUES (4, 'B12', NULL, -5.9, 106.245, 0.00, 92.0, '2026-09-07 07:40:00+00');


--
-- Data for Name: geofence; Type: TABLE DATA; Schema: telemetry; Owner: -
--

INSERT INTO telemetry.geofence VALUES (1, 'F-B04', 'Polygon Blok B-04', 'PENGERUKAN', '0103000020E61000000100000005000000EC51B81E857B5A4048E17A14AE4717C066666666667E5A401283C0CAA14517C03BDF4F8D977E5A40E17A14AE476117C0C1CAA145B67B5A4017D9CEF7536317C0EC51B81E857B5A4048E17A14AE4717C0', NULL);
INSERT INTO telemetry.geofence VALUES (2, 'F-SITEG', 'Polygon Site G', 'SITE_BONGKAR', '0103000020E61000000100000005000000AE47E17A14965A40D7A3703D0AD717C0D578E92631985A40A245B6F3FDD417C0B81E85EB51985A4021B0726891ED17C091ED7C3F35965A40560E2DB29DEF17C0AE47E17A14965A40D7A3703D0AD717C0', NULL);
INSERT INTO telemetry.geofence VALUES (3, 'F-ETAP2', 'Polygon Etap 2', 'SITE_BONGKAR', '0103000020E610000001000000050000009CC420B072985A40713D0AD7A3F017C00AD7A3703D9A5A403BDF4F8D97EE17C0EE7C3F355E9A5A40BA490C022B0718C07F6ABC7493985A40F0A7C64B370918C09CC420B072985A40713D0AD7A3F017C0', NULL);
INSERT INTO telemetry.geofence VALUES (4, 'F-B07', 'Polygon Blok B-07', 'PENGERUKAN', '0103000020E610000001000000050000005C8FC2F5287C5A40295C8FC2F52817C0D7A3703D0A875A40AE47E17A142E17C048E17A14AE875A407B14AE47E17A17C0CDCCCCCCCC7C5A40F6285C8FC27517C05C8FC2F5287C5A40295C8FC2F52817C0', NULL);
INSERT INTO telemetry.geofence VALUES (5, 'F-MARJAYA', 'Zona Dok Marina Jaya', 'DOK', '0103000020E6100000010000000500000079E92631088C5A4008AC1C5A64BB17C079E92631088C5A405EBA490C02AB17C021B07268918D5A405EBA490C02AB17C021B07268918D5A4008AC1C5A64BB17C079E92631088C5A4008AC1C5A64BB17C0', NULL);


--
-- Data for Name: geofence_event; Type: TABLE DATA; Schema: telemetry; Owner: -
--

INSERT INTO telemetry.geofence_event VALUES (1, 'SL05', 2, 'EXIT', '2026-09-07 07:32:00+00');
INSERT INTO telemetry.geofence_event VALUES (2, 'SL02', 2, 'ENTRY', '2026-09-06 19:00:00+00');
INSERT INTO telemetry.geofence_event VALUES (3, 'B12', 5, 'EXIT', '2026-09-07 07:35:00+00');
INSERT INTO telemetry.geofence_event VALUES (4, 'M03', 5, 'ENTRY', '2026-09-06 11:20:00+00');
INSERT INTO telemetry.geofence_event VALUES (5, 'LI02', 5, 'ENTRY', '2026-09-06 10:05:00+00');
INSERT INTO telemetry.geofence_event VALUES (6, 'B12', 5, 'ENTRY', '2026-09-04 16:00:00+00');
INSERT INTO telemetry.geofence_event VALUES (7, 'B07', 5, 'ENTRY', '2026-09-05 08:40:00+00');
INSERT INTO telemetry.geofence_event VALUES (8, 'SL07', 5, 'ENTRY', '2026-09-05 09:10:00+00');


--
-- Data for Name: vessel_device; Type: TABLE DATA; Schema: telemetry; Owner: -
--

INSERT INTO telemetry.vessel_device VALUES (1, 'SL02', 'AIS', 'AIS-SL02-236194', '2025-11-04', '2026-09-11 04:29:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (2, 'SL02', 'STARLINK', 'STX-SL02-7781', '2025-11-04', '2026-09-11 04:33:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (3, 'SL05', 'AIS', 'AIS-SL05-236210', '2025-12-18', '2026-09-11 04:20:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (4, 'SL05', 'STARLINK', 'STX-SL05-7812', '2025-12-18', '2026-09-08 04:37:38.961981+00', 'OFFLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (5, 'SL09', 'AIS', 'AIS-SL09-236241', '2026-01-22', '2026-09-10 02:37:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (6, 'SL09', 'STARLINK', 'STX-SL09-7844', '2026-01-22', '2026-09-11 04:26:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (7, 'M03', 'AIS', 'AIS-M03-236288', '2025-10-09', '2026-09-11 04:16:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (8, 'M03', 'STARLINK', 'STX-M03-7860', '2025-10-09', '2026-09-11 04:28:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (9, 'B07', 'AIS', 'AIS-B07-236301', '2026-05-27', '2026-09-11 04:23:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (10, 'B07', 'STARLINK', 'STX-B07-7877', '2026-05-27', '2026-09-11 04:31:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (11, 'B12', 'AIS', 'AIS-B12-236333', '2026-02-14', '2026-09-09 04:37:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (12, 'SL07', 'AIS', 'AIS-SL07-236352', '2026-03-03', '2026-09-11 04:06:38.961981+00', 'ONLINE', NULL);
INSERT INTO telemetry.vessel_device VALUES (13, 'LI02', 'AIS', 'AIS-LI02-236360', '2026-03-03', NULL, 'MAINTENANCE', NULL);


--
-- Data for Name: voyage; Type: TABLE DATA; Schema: voyage; Owner: -
--

INSERT INTO voyage.voyage VALUES (2, 'SL02', 'TRP-2026-0907', -5.86, 106.02, 9.30, 97.0, '2026-09-06 13:00:00+00');
INSERT INTO voyage.voyage VALUES (5, 'SL02', 'TRP-2026-0907', -5.96, 106.3, 9.60, 94.0, '2026-09-06 18:00:00+00');
INSERT INTO voyage.voyage VALUES (6, 'SL02', 'TRP-2026-0907', -5.97, 106.36, 4.20, 92.0, '2026-09-06 19:00:00+00');
INSERT INTO voyage.voyage VALUES (4, 'SL02', 'TRP-2026-0907', -5.93, 106.22, 9.60, 95.0, '2026-09-06 17:00:00+00');
INSERT INTO voyage.voyage VALUES (1, 'SL02', 'TRP-2026-0907', -5.83, 105.95, 9.10, 95.0, '2026-09-06 11:00:00+00');
INSERT INTO voyage.voyage VALUES (3, 'SL02', 'TRP-2026-0907', -5.9, 106.12, 9.50, 96.0, '2026-09-06 15:00:00+00');


--
-- Name: deposit_deposit_id_seq; Type: SEQUENCE SET; Schema: buyer; Owner: -
--

SELECT pg_catalog.setval('buyer.deposit_deposit_id_seq', 1, false);


--
-- Name: deposit_transaction_dep_trans_id_seq; Type: SEQUENCE SET; Schema: buyer; Owner: -
--

SELECT pg_catalog.setval('buyer.deposit_transaction_dep_trans_id_seq', 1, false);


--
-- Name: ledger_hist_id_seq; Type: SEQUENCE SET; Schema: buyer; Owner: -
--

SELECT pg_catalog.setval('buyer.ledger_hist_id_seq', 1, false);


--
-- Name: site_buyer_site_id_seq; Type: SEQUENCE SET; Schema: buyer; Owner: -
--

SELECT pg_catalog.setval('buyer.site_buyer_site_id_seq', 3, true);


--
-- Name: bap_bap_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.bap_bap_id_seq', 1, false);


--
-- Name: bap_correction_bap_correction_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.bap_correction_bap_correction_id_seq', 1, false);


--
-- Name: bap_objection_bap_objection_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.bap_objection_bap_objection_id_seq', 1, false);


--
-- Name: delivery_order_do_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.delivery_order_do_id_seq', 1, false);


--
-- Name: purchase_order_po_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.purchase_order_po_id_seq', 1, false);


--
-- Name: sales_contract_sales_contract_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.sales_contract_sales_contract_id_seq', 1, false);


--
-- Name: sand_spec_sand_spec_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.sand_spec_sand_spec_id_seq', 1, false);


--
-- Name: standby_claim_standby_claim_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.standby_claim_standby_claim_id_seq', 1, false);


--
-- Name: document_document_id_seq; Type: SEQUENCE SET; Schema: document; Owner: -
--

SELECT pg_catalog.setval('document.document_document_id_seq', 1, false);


--
-- Name: ews_event_ews_event_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.ews_event_ews_event_id_seq', 4, true);


--
-- Name: mon_report_mon_report_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.mon_report_mon_report_id_seq', 1, false);


--
-- Name: mon_schedule_schedule_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.mon_schedule_schedule_id_seq', 1, false);


--
-- Name: mon_work_order_wo_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.mon_work_order_wo_id_seq', 1, false);


--
-- Name: reading_detail_reading_detail_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.reading_detail_reading_detail_id_seq', 117, true);


--
-- Name: remediation_remediation_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.remediation_remediation_id_seq', 1, false);


--
-- Name: cost_entry_cost_entry_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.cost_entry_cost_entry_id_seq', 1, false);


--
-- Name: invoice_invoice_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.invoice_invoice_id_seq', 1, false);


--
-- Name: journal_journal_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.journal_journal_id_seq', 1, false);


--
-- Name: journal_line_journal_line_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.journal_line_journal_line_id_seq', 22, true);


--
-- Name: pnbp_charge_pnbp_charge_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.pnbp_charge_pnbp_charge_id_seq', 1, false);


--
-- Name: pnbp_tahap_awal_tahap_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.pnbp_tahap_awal_tahap_id_seq', 2, true);


--
-- Name: pnbp_tarif_tarif_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.pnbp_tarif_tarif_id_seq', 3, true);


--
-- Name: capa_capa_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.capa_capa_id_seq', 3, true);


--
-- Name: certificate_certificate_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.certificate_certificate_id_seq', 16, true);


--
-- Name: incident_incident_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.incident_incident_id_seq', 4, true);


--
-- Name: induction_induction_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.induction_induction_id_seq', 6, true);


--
-- Name: inspection_inspection_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.inspection_inspection_id_seq', 20, true);


--
-- Name: toolbox_meeting_ttm_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.toolbox_meeting_ttm_id_seq', 24, true);


--
-- Name: email_outbox_outbox_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.email_outbox_outbox_id_seq', 3, true);


--
-- Name: log_notif_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.log_notif_id_seq', 12, true);


--
-- Name: report_schedule_schedule_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.report_schedule_schedule_id_seq', 1, true);


--
-- Name: rule_rule_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.rule_rule_id_seq', 7, true);


--
-- Name: schedule_plan_plan_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.schedule_plan_plan_id_seq', 4, true);


--
-- Name: schedule_proposal_proposal_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.schedule_proposal_proposal_id_seq', 2, true);


--
-- Name: shipment_instruction_si_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.shipment_instruction_si_id_seq', 28, true);


--
-- Name: site_permit_site_permit_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.site_permit_site_permit_id_seq', 1, false);


--
-- Name: trip_trip_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.trip_trip_id_seq', 28, true);


--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE SET; Schema: param; Owner: -
--

SELECT pg_catalog.setval('param.audit_log_audit_id_seq', 2, true);


--
-- Name: charter_contract_charter_contract_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.charter_contract_charter_contract_id_seq', 1, false);


--
-- Name: invoice_partner_invoice_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.invoice_partner_invoice_id_seq', 1, false);


--
-- Name: payment_allocation_payment_allocation_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.payment_allocation_payment_allocation_id_seq', 1, false);


--
-- Name: payment_payment_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.payment_payment_id_seq', 1, false);


--
-- Name: rate_card_rate_card_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.rate_card_rate_card_id_seq', 1, false);


--
-- Name: statement_line_statement_line_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.statement_line_statement_line_id_seq', 1, false);


--
-- Name: draft_survey_draft_survey_id_seq; Type: SEQUENCE SET; Schema: survey; Owner: -
--

SELECT pg_catalog.setval('survey.draft_survey_draft_survey_id_seq', 9, true);


--
-- Name: ais_position_position_id_seq; Type: SEQUENCE SET; Schema: telemetry; Owner: -
--

SELECT pg_catalog.setval('telemetry.ais_position_position_id_seq', 4, true);


--
-- Name: geofence_event_event_id_seq; Type: SEQUENCE SET; Schema: telemetry; Owner: -
--

SELECT pg_catalog.setval('telemetry.geofence_event_event_id_seq', 8, true);


--
-- Name: geofence_geofence_id_seq; Type: SEQUENCE SET; Schema: telemetry; Owner: -
--

SELECT pg_catalog.setval('telemetry.geofence_geofence_id_seq', 5, true);


--
-- Name: vessel_device_device_id_seq; Type: SEQUENCE SET; Schema: telemetry; Owner: -
--

SELECT pg_catalog.setval('telemetry.vessel_device_device_id_seq', 13, true);


--
-- Name: voyage_voyage_id_seq; Type: SEQUENCE SET; Schema: voyage; Owner: -
--

SELECT pg_catalog.setval('voyage.voyage_voyage_id_seq', 1, false);


--
-- PostgreSQL database dump complete
--

\unrestrict u6jhGoME6bbgrhfOGYcjXNuCignd0FyH6dcwgDFOgUMdAZauuTvR6yVnOdjPDbI

