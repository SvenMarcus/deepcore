local function make_fake_slot_store()
    return {
        __slots = {},

        read = function(self, key)
            return self.__slots[key]
        end,

        write = function(self, key, text)
            self.__slots[key] = text
        end,

        is_empty = function(self, key)
            local text = self.__slots[key]
            return text == nil or text == ""
        end,

        free = function(self, key)
            self.__slots[key] = nil
        end,

        clear = function(self)
            self.__slots = {}
        end
    }
end

return make_fake_slot_store
