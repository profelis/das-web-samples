
class ServerTime extends preact.Component {
  state = { time: "" }
  componentDidMount() {
    jrpc.on("serverTime", data => {
      console.log("serverTime message ", data)
      this.setState({ time: String(data) })
    })
  }

  render({ }, { time }) {
    return <p> Server time: {time}</p>
  }
}

preactCustomElement(ServerTime, "server-time")
