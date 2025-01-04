options = {}
options[:logger] = $logger if !defined?(RedisClient)

Searchkick.redis =
  if !defined?(Redis)
    RedisClient.config.new_pool
  elsif defined?(ConnectionPool)
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
RedisClient.register(RedisInstrumentation) if defined?(RedisClient)
