const http = require('http')
const path = require('path')

const app = path.basename(__dirname)

const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'application/json'});
  res.write(JSON.stringify({ app, message: null }));
  res.end();
})

const host = process.env.HOST || '0.0.0.0'
const port  = process.env.PORT || 80
console.log(`Server listening at http://${host}:${port}`)
server.listen(port, host)
