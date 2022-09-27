options = {}
options[:logger] = $logger if Redis::VERSION.to_i < 5

Searchkick.redis =
  if defined?(ConnectionPool)
    ConnectionPool.new { Redis.new(**options) }
  else
    Redis.new(**options)
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
RedisClient.register(RedisInstrumentation) if Redis::VERSION.to_i >= 5
