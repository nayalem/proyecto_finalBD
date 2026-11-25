--replicacion.sql anillo y catalogos (nayalem)
\set ON_ERROR_STOP on
SET client_min_messages = warning;
--publicar
\if :publicar
SELECT format('CREATE PUBLICATION pub_frag FOR TABLE frag.voluntario_%s, frag.participacion_%s', :yo, :yo) \gexec
SELECT 'CREATE PUBLICATION pub_catalogos FOR TABLE organizacion, actividad' WHERE :yo = 1 \gexec
\else
--suscribir al nodo anterior
SELECT format('CREATE SUBSCRIPTION sub_frag_%s CONNECTION %L PUBLICATION pub_frag', :yo,
              format('host=%s port=%s dbname=postgres user=postgres password=postgres', :'host_ant', :'port_ant')) \gexec
--catalogos desde a
SELECT format('CREATE SUBSCRIPTION sub_catalogos_%s CONNECTION %L PUBLICATION pub_catalogos WITH (copy_data = false)', :yo,
              format('host=%s port=%s dbname=postgres user=postgres password=postgres', :'host_a', :'port_a'))
WHERE :yo <> 1 \gexec
\endif
