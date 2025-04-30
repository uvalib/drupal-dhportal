$settings['config_sync_directory'] = '/opt/drupal/util/drupal-dh/local/ddev/config';
$databases['default']['default'] = array(
  'database' => getenv('MYSQL_DATABASE'),
  'username' => getenv( 'MYSQL_USER' ),
  'password' => getenv( 'MYSQL_PASSWORD' ),
  'host' => getenv( 'MYSQL_HOST' ),
  'port' => 3306,
  'prefix' => '',
  'collation' => 'utf8mb4_general_ci',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'driver' => 'mysql',
); 

$databases['migrate']['default'] = array (
  'database' => 'drupal7migrate',
  'username' => 'db',
  'password' => 'db',
  'prefix' => '',
  'host' => 'db',
  'port' => '3306',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'driver' => 'mysql',
);
