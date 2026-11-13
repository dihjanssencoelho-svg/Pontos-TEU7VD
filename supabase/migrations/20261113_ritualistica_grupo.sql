-- Adiciona Ritualística como grupo permitido, preservando todos os pontos cadastrados.
alter table public.points drop constraint if exists points_work_group_check;
alter table public.points
  add constraint points_work_group_check
  check (work_group in ('Orixás', 'Linhas de trabalho', 'Ritualística'));
