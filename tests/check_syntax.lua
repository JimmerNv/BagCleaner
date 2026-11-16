for _,file in ipairs({'Core.lua','UI.lua','Titan.lua'}) do
  assert(loadfile(file))
  print('SYNTAX OK '..file)
end
