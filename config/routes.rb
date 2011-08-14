# Check out https://github.com/joshbuddy/http_router for more information on HttpRouter
HttpRouter.new do
  add('/').to(HomeAction)
  get('/websocket').to(ChatAction)
  get('/list/:id').to(ListAction)
  get('/cleanup/:id').to(CleanupAction)
end
