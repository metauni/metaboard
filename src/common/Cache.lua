local Cache = {
  __cache = {}
}

function Cache.Get(class)
  local classCache = Cache.__cache[class]
  if not classCache then
      classCache = {}
      Cache.__cache[class] = classCache
  end
  return table.remove(classCache) or Instance.new(class)
end

function Cache.Release(instance)
  local class = instance.ClassName
  local classCache = Cache.__cache[class]
  if not classCache then
      classCache = {}
      Cache.__cache[class] = classCache
  end
  table.insert(classCache, instance)
end

return Cache