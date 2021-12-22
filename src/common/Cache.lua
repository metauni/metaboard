local Config = require(script.Parent.Config)

local Cache = {
  __cache = {}
}

if Config.UseCache == false then
  return {
    Get = Instance.new,
    Release = function(instance) instance:Destroy() end
  }
end

function Cache.Get(class)
  local classCache = Cache.__cache[class]
  if not classCache then
      classCache = {}
      Cache.__cache[class] = classCache
  end
  return table.remove(classCache) or Instance.new(class)
end

function Cache.Release(instance)
  -- We release instances within this function, because there is no
  -- simple way to deparent before/after this function that doesn't break
  -- if Config.UseCache == false
  instance.Parent = nil
  local class = instance.ClassName
  local classCache = Cache.__cache[class]
  if not classCache then
      classCache = {}
      Cache.__cache[class] = classCache
  end
  table.insert(classCache, instance)
end

return Cache