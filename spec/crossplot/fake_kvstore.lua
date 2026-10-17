local function make_fake_kvstore()
    return {
        __store = {},
        store = function(self, key, value)
            self.__store[key] = value
            return true
        end,

        store_serialized = function(self, key, serialized)
            self.__store[key] = loadstring(serialized)()
            return true
        end,

        get = function(self, key)
            return self.__store[key]
        end,

        take = function(self, key)
            local value = self.__store[key]
            self.__store[key] = nil
            return value
        end,

        is_empty = function(self, key)
            local value = self.__store[key]
            return value == nil or value == ""
        end,

        free = function(self, key)
            self.__store[key] = nil
        end,

        clear = function(self)
            self.__store = {}
        end
    }
end


return make_fake_kvstore
