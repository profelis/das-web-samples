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
    let start = 0
    for (let i = 0; i < text.length; ++i) {
      if (text[i] == "}" || text[i] == "]") {
        try {
          let sub = text.substring(start, i + 1)
          JSON.parse(sub)
          jrpc.messageHandler(sub)
          start = i + 1
        } catch (e) {
          console.log("can't parse", text.substring(start, i + 1))
         }
      }
    }
    if (start < text.length - 1)
    {
      let sub = text.substring(start)
      jrpc.messageHandler(sub)
    }
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
