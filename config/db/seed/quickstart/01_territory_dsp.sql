-- Quickstart seed: territory levels for dsp-db (demo only, SRID 4674).
-- Do not use in production. Geometries are heavily simplified.
-- Neighbouring boundaries are shared: states touch without gaps or overlaps.
TRUNCATE dsp.area_of_interest, dsp.territory_level_3, dsp.territory_level_2, dsp.territory_level_1 CASCADE;

INSERT INTO dsp.territory_level_1 (id, name, boundary_box, centroid_coordinates) VALUES
  ('BR', 'Brazil', ST_MakeEnvelope(-73.9475, -33.7438, -34.7945, 5.2718, 4674), ST_SetSRID(ST_Point(-53.0738, -10.7800), 4674));

INSERT INTO dsp.territory_level_2 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('1', 'Norte', 'BR', ST_MakeEnvelope(-73.9475, -13.6873, -45.6996, 5.2718, 4674), ST_SetSRID(ST_Point(-59.2106, -4.6106), 4674));
INSERT INTO dsp.territory_level_2 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('2', 'Nordeste', 'BR', ST_MakeEnvelope(-48.7552, -18.3332, -34.7945, -1.0493, 4674), ST_SetSRID(ST_Point(-41.7426, -8.6383), 4674));
INSERT INTO dsp.territory_level_2 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('3', 'Sudeste', 'BR', ST_MakeEnvelope(-53.1052, -25.3123, -39.6660, -14.2407, 4674), ST_SetSRID(ST_Point(-45.4823, -19.7258), 4674));
INSERT INTO dsp.territory_level_2 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('4', 'Sul', 'BR', ST_MakeEnvelope(-57.5680, -33.7438, -48.0995, -22.5199, 4674), ST_SetSRID(ST_Point(-52.2320, -27.6290), 4674));
INSERT INTO dsp.territory_level_2 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('5', 'Centro-Oeste', 'BR', ST_MakeEnvelope(-61.6259, -24.0590, -45.9326, -7.3564, 4674), ST_SetSRID(ST_Point(-54.3073, -15.3005), 4674));

INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('AC', 'Acre', '1', ST_MakeEnvelope(-73.9475, -11.1456, -66.6274, -7.1118, 4674), ST_SetSRID(ST_Point(-70.4737, -9.2172), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('AL', 'Alagoas', '2', ST_MakeEnvelope(-38.2375, -10.4870, -35.1554, -8.8168, 4674), ST_SetSRID(ST_Point(-36.6195, -9.5206), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('AM', 'Amazonas', '1', ST_MakeEnvelope(-73.8016, -9.8180, -56.4021, 2.2440, 4674), ST_SetSRID(ST_Point(-64.6566, -4.1546), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('AP', 'Amapá', '1', ST_MakeEnvelope(-54.8723, -1.1571, -49.8817, 4.5088, 4674), ST_SetSRID(ST_Point(-51.9626, 1.4468), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('BA', 'Bahia', '2', ST_MakeEnvelope(-46.5522, -18.3332, -37.3419, -8.5421, 4674), ST_SetSRID(ST_Point(-41.7237, -12.4781), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('CE', 'Ceará', '2', ST_MakeEnvelope(-41.4123, -7.8096, -37.2527, -2.8111, 4674), ST_SetSRID(ST_Point(-39.6155, -5.0922), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('DF', 'Distrito Federal', '5', ST_MakeEnvelope(-48.2778, -16.0500, -47.3093, -15.5018, 4674), ST_SetSRID(ST_Point(-47.7956, -15.7800), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('ES', 'Espirito Santo', '3', ST_MakeEnvelope(-41.8736, -21.3003, -39.6660, -17.8919, 4674), ST_SetSRID(ST_Point(-40.6681, -19.5762), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('GO', 'Goiás', '5', ST_MakeEnvelope(-53.2350, -19.4675, -45.9326, -12.4954, 4674), ST_SetSRID(ST_Point(-49.6261, -16.0422), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('MA', 'Maranhão', '2', ST_MakeEnvelope(-48.7552, -10.2507, -41.7963, -1.0493, 4674), ST_SetSRID(ST_Point(-45.2923, -5.0785), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('MG', 'Minas Gerais', '3', ST_MakeEnvelope(-51.0454, -22.9003, -39.8568, -14.2407, 4674), ST_SetSRID(ST_Point(-44.6745, -18.4569), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('MS', 'Mato Grosso do Sul', '5', ST_MakeEnvelope(-58.1314, -24.0590, -50.9350, -17.1795, 4674), ST_SetSRID(ST_Point(-54.8415, -20.3284), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('MT', 'Mato Grosso', '5', ST_MakeEnvelope(-61.6259, -18.0340, -50.2248, -7.3564, 4674), ST_SetSRID(ST_Point(-55.9136, -12.9530), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('PA', 'Pará', '1', ST_MakeEnvelope(-58.8955, -9.8412, -46.0615, 2.5910, 4674), ST_SetSRID(ST_Point(-53.0729, -3.9784), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('PB', 'Paraíba', '2', ST_MakeEnvelope(-38.7563, -8.2993, -34.7945, -6.0496, 4674), ST_SetSRID(ST_Point(-36.8386, -7.1206), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('PE', 'Pernambuco', '2', ST_MakeEnvelope(-41.3580, -9.4824, -34.8348, -7.2739, 4674), ST_SetSRID(ST_Point(-37.9862, -8.3267), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('PI', 'Piauí', '2', ST_MakeEnvelope(-46.0124, -10.9288, -40.4277, -2.7573, 4674), ST_SetSRID(ST_Point(-42.9700, -7.3947), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('PR', 'Paraná', '4', ST_MakeEnvelope(-54.6191, -26.6882, -48.0995, -22.5199, 4674), ST_SetSRID(ST_Point(-51.6131, -24.6357), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('RJ', 'Rio de Janeiro', '3', ST_MakeEnvelope(-44.8893, -23.3656, -40.9642, -20.7657, 4674), ST_SetSRID(ST_Point(-42.6612, -22.1959), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('RN', 'Rio Grande do Norte', '2', ST_MakeEnvelope(-38.5626, -6.9368, -34.9685, -4.8314, 4674), ST_SetSRID(ST_Point(-36.6797, -5.8335), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('RO', 'Rondônia', '1', ST_MakeEnvelope(-66.8103, -13.6873, -59.7929, -7.9759, 4674), ST_SetSRID(ST_Point(-62.8425, -10.9105), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('RR', 'Roraima', '1', ST_MakeEnvelope(-64.8105, -1.4387, -58.8955, 5.2718, 4674), ST_SetSRID(ST_Point(-61.3925, 2.0785), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('RS', 'Rio Grande do Sul', '4', ST_MakeEnvelope(-57.5680, -33.7438, -49.7266, -27.1410, 4674), ST_SetSRID(ST_Point(-53.2375, -29.7869), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('SC', 'Santa Catarina', '4', ST_MakeEnvelope(-53.8365, -29.3288, -48.3757, -25.9768, 4674), ST_SetSRID(ST_Point(-50.4716, -27.2434), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('SE', 'Sergipe', '2', ST_MakeEnvelope(-38.2274, -11.5578, -36.4036, -9.5150, 4674), ST_SetSRID(ST_Point(-37.4479, -10.5826), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('SP', 'São Paulo', '3', ST_MakeEnvelope(-53.1052, -25.3123, -44.1843, -19.7797, 4674), ST_SetSRID(ST_Point(-48.7325, -22.2595), 4674));
INSERT INTO dsp.territory_level_3 (id, name, parent_id, boundary_box, centroid_coordinates) VALUES
  ('TO', 'Tocantins', '1', ST_MakeEnvelope(-50.7393, -13.3692, -45.6996, -5.1684, 4674), ST_SetSRID(ST_Point(-48.3353, -10.1553), 4674));
