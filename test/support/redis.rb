Searchkick.redis =
  if defined?(ConnectionPool)
    ConnectionPool.new { Redis.new }
  else
    Redis.new
  end

module RedisInstrumentation
  def call(command, redis_config)
    $logger.info "[redis] #{command.inspect}"
    super
  end

  def call_pipelined(commands, redis_config)
    $logger.info "[redis] #{commands.inspect}"
    super
  end
end
RedisClient.register(RedisInstrumentation)
