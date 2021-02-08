"using strict"

var jrpc = new simple_jsonrpc()
var socket

var newSocketListeners = []

function createSocket() {
  socket = new WebSocket("ws://localhost:1000")
  for (let fn of newSocketListeners)
    fn.call(null, socket)
  socket.onmessage = async event => {
    let text = await event.data.text()
    // split multiple json messages in one string
    let lines = text.split("\n")
    let i = 0;
    let str = ""
    for (; i < lines.length; ++i) {
      str += lines[i]
      if (lines[i] == "}") {
        try {
          JSON.parse(str)
          jrpc.messageHandler(str)
          str = ""
        } catch (e) { }
      }
    }
    if (str.length > 0)
      jrpc.messageHandler(str)
  }
  jrpc.toStream = _msg => socket.send(_msg)

  socket.onopen = data => console.log("Socket connected: ", data)
  socket.onerror = error => console.error("socket error: " + error.message)

  socket.onclose = function (event) {
    if (event.wasClean) {
      console.info('Connection close was clean')
    } else {
      console.error('Connection suddenly close')
    }
    console.info('socket close code : ' + event.code + ' reason: ' + event.reason)
    console.log(`reconnect... `)
    setTimeout(createSocket, 1000)
  }
}
