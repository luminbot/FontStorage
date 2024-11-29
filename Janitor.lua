local janitor = { }

do -- janitor 
    -- Compiled with L+ C Edition
    -- Janitor
    -- Original by Validark
    -- Modifications by pobammer
    -- roblox-ts support by OverHash and Validark
    -- LinkToInstance fixed by Elttob.
    -- Cleanup edge cases fixed by codesenseAye.

    local GetPromiseLibrary = function() return false end
        --[[ 	A wrapper for an `RBXScriptConnection`. Makes the Janitor clean up when the instance is destroyed. This was created by Corecii.  	@class RbxScriptConnection ]] 
        local RbxScriptConnection = {} 
        RbxScriptConnection.Connected = true 
        RbxScriptConnection.__index = RbxScriptConnection  
        --[[ 	@prop Connected boolean 	@within RbxScriptConnection  	Whether or not this connection is still connected.  	Disconnects the signal. ]] 
        function RbxScriptConnection:Disconnect() 	
            if self.Connected then 		
                self.Connected = false 		
                self.Connection:Disconnect() 	
            end 
        end  
        function RbxScriptConnection._new(RBXScriptConnection: RBXScriptConnection) 	
            return setmetatable({ 		
                Connection = RBXScriptConnection 	
            }, RbxScriptConnection) 
        end  
        function RbxScriptConnection:__tostring() 	
            return "RbxScriptConnection" 
        end  
        local function Symbol(Name: string) 	
            local self = newproxy(true) 	
            local Metatable = getmetatable(self) 	

            function Metatable.__tostring() 		
                return Name 	
            end  	

            return self 
        end  

    local FoundPromiseLibrary, Promise = GetPromiseLibrary()

    local IndicesReference = Symbol("IndicesReference")
    local LinkToInstanceIndex = Symbol("LinkToInstanceIndex")

    local INVALID_METHOD_NAME = "Object is a %s and as such expected `true` for the method name and instead got %s. Traceback: %s"
    local METHOD_NOT_FOUND_ERROR = "Object %s doesn't have method %s, are you sure you want to add it Traceback: %s"
    local NOT_A_PROMISE = "Invalid argument #1 to 'Janitor:AddPromise' (Promise expected, got %s (%s)) Traceback: %s"

    --[[
        Janitor is a light-weight, flexible object for cleaning up connections, instances, or anything. This implementation covers all use cases,
        as it doesn't force you to rely on naive typechecking to guess how an instance should be cleaned up.
        Instead, the developer may specify any behavior for any object.

        @class Janitor
    ]]
    local Janitor = {}
    Janitor.ClassName = "Janitor"
    Janitor.CurrentlyCleaning = true
    Janitor[IndicesReference] = nil
    Janitor.__index = Janitor

    --[[
        @prop CurrentlyCleaning boolean
        @within Janitor

        Whether or not the Janitor is currently cleaning up.
    ]]

    local TypeDefaults = {
        ["function"] = true,
        thread = true,
        RBXScriptConnection = "Disconnect"
    }

    --[[
        Instantiates a new Janitor object.
        @return Janitor
    ]]
    function Janitor.new()
        return setmetatable({
            CurrentlyCleaning = false,
            [IndicesReference] = nil
        }, Janitor)
    end

    --[[
        Determines if the passed object is a Janitor. This checks the metatable directly.

        @param Object any -- The object you are checking.
        @return boolean -- `true` if `Object` is a Janitor.
    ]]
    function Janitor.Is(Object: any): boolean
        return type(Object) == "table" and getmetatable(Object) == Janitor
    end

    function Janitor:Add(Object: T, MethodName: StringOrTrue, Index: any): T
        if Index then
            self:Remove(Index)

            local This = self[IndicesReference]
            if not This then
                This = {}
                self[IndicesReference] = This
            end

            This[Index] = Object
        end

        local TypeOf = typeof(Object)
        local NewMethodName = MethodName or TypeDefaults[TypeOf] or "Destroy"

        self[Object] = NewMethodName
        return Object
    end

    function Janitor:AddPromise(PromiseObject)
        if FoundPromiseLibrary then
            if not Promise.is(PromiseObject) then
                error(string.format(NOT_A_PROMISE, typeof(PromiseObject), tostring(PromiseObject), debug.traceback(nil, 2)))
            end

            if PromiseObject:getStatus() == Promise.Status.Started then
                local Id = newproxy(false)
                local NewPromise = self:Add(Promise.new(function(Resolve, _, OnCancel)
                    if OnCancel(function()
                            PromiseObject:cancel()
                        end) then
                        return
                    end

                    Resolve(PromiseObject)
                end), "cancel", Id)

                NewPromise:finallyCall(self.Remove, self, Id)
                return NewPromise
            else
                return PromiseObject
            end
        else
            return PromiseObject
        end
    end

    function Janitor:Remove(Index: any)
        local This = self[IndicesReference]

        if This then
            local Object = This[Index]

            if Object then
                local MethodName = self[Object]

                if MethodName then
                    if MethodName == true then
                        if type(Object) == "function" then
                            Object()
                        else
                            task.cancel(Object)
                        end
                    else
                        local ObjectMethod = Object[MethodName]
                        if ObjectMethod then
                            ObjectMethod(Object)
                        end
                    end

                    self[Object] = nil
                end

                This[Index] = nil
            end
        end

        return self
    end

    function Janitor:RemoveList(...)
        local This = self[IndicesReference]
        if This then
            local Length = select("#", ...)
            if Length == 1 then
                return self:Remove(...)
            else
                for Index = 1, Length do
                    -- MACRO
                    local Object = This[select(Index, ...)]
                    if Object then
                        local MethodName = self[Object]

                        if MethodName then
                            if MethodName == true then
                                if type(Object) == "function" then
                                    Object()
                                else
                                    task.cancel(Object)
                                end
                            else
                                local ObjectMethod = Object[MethodName]
                                if ObjectMethod then
                                    ObjectMethod(Object)
                                end
                            end

                            self[Object] = nil
                        end

                        This[Index] = nil
                    end
                end
            end
        end

        return self
    end

    function Janitor:Get(Index: any): any
        local This = self[IndicesReference]
        return (This) and (This[Index]) or (nil)
    end

    local function GetFenv(self)
        return function()
            for Object, MethodName in next, self do
                if Object ~= IndicesReference then
                    return Object, MethodName
                end
            end
        end
    end

    function Janitor:Cleanup()
        if not self.CurrentlyCleaning then
            self.CurrentlyCleaning = nil

            local Get = GetFenv(self)
            local Object, MethodName = Get()

            while Object and MethodName do -- changed to a while loop so that if you add to the janitor inside of a callback it doesn't get untracked (instead it will loop continuously which is a lot better than a hard to pindown edgecase)
                if MethodName == true then
                    if type(Object) == "function" then
                        Object()
                    else
                        task.cancel(Object)
                    end
                else
                    local ObjectMethod = Object[MethodName]
                    if ObjectMethod then
                        ObjectMethod(Object)
                    end
                end

                self[Object] = nil
                Object, MethodName = Get()
            end

            local This = self[IndicesReference]
            if This then
                table.clear(This)
                self[IndicesReference] = {}
            end

            self.CurrentlyCleaning = false
        end
    end

    function Janitor:Destroy()
        -- jayhaxx specific 
        unloaded = true

        self:Cleanup()
        table.clear(self)
        setmetatable(self, nil)
    end

    Janitor.__call = Janitor.Cleanup

    function Janitor:LinkToInstance(Object: Instance, AllowMultiple: boolean): RBXScriptConnection
        local IndexToUse = AllowMultiple and newproxy(false) or LinkToInstanceIndex

        return self:Add(Object.Destroying:Connect(function()
            self:Cleanup()
        end), "Disconnect", IndexToUse)
    end

    function Janitor:LegacyLinkToInstance(Object: Instance, AllowMultiple: boolean): RbxScriptConnection
        local Connection
        local IndexToUse = AllowMultiple and newproxy(false) or LinkToInstanceIndex
        local IsNilParented = Object.Parent == nil
        local ManualDisconnect = setmetatable({}, RbxScriptConnection)

        local function ChangedFunction(_DoNotUse, NewParent)
            if ManualDisconnect.Connected then
                _DoNotUse = nil
                IsNilParented = NewParent == nil

                if IsNilParented then
                    task.defer(function()
                        if not ManualDisconnect.Connected then
                            return
                        elseif not Connection.Connected then
                            self:Cleanup()
                        else
                            while IsNilParented and Connection.Connected and ManualDisconnect.Connected do
                                task.wait()
                            end

                            if ManualDisconnect.Connected and IsNilParented then
                                self:Cleanup()
                            end
                        end
                    end)
                end
            end
        end

        Connection = Object.AncestryChanged:Connect(ChangedFunction)
        ManualDisconnect.Connection = Connection

        if IsNilParented then
            ChangedFunction(nil, Object.Parent)
        end

        Object = nil
        return self:Add(ManualDisconnect, "Disconnect", IndexToUse)
    end

    function Janitor:LinkToInstances(...)
        local ManualCleanup = Janitor.new()
        for _, Object in ipairs({...}) do
            ManualCleanup:Add(self:LinkToInstance(Object, true), "Disconnect")
        end

        return ManualCleanup
    end

    function Janitor:__tostring()
        return "Janitor"
    end

    table.freeze(Janitor)
    janitor = Janitor
end

return janitor
