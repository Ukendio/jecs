local types = require(script.Parent.types)

return function(connector: types.IncomingConnector | types.OutgoingConnector)
	return `{connector.host}\0{connector.from_vm or connector.to_vm}`
end