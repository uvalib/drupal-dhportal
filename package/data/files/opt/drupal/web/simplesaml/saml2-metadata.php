<?php

declare(strict_types=1);

require_once('_include.php');

use SimpleSAML\Configuration;
use SimpleSAML\Metadata\MetaDataStorageHandler;
use SimpleSAML\Utils;

// Set content type to XML
header('Content-Type: application/samlmetadata+xml');

// Get the entity ID from the request
$entityId = $_REQUEST['set'] ?? 'default-sp';

try {
    // Get metadata storage handler
    $metadataHandler = new MetaDataStorageHandler();
    
    // Get SP metadata
    $metadata = $metadataHandler->getMetaData($entityId, 'saml20-sp-hosted');
    
    if ($metadata === null) {
        throw new Exception('Metadata not found for entity: ' . $entityId);
    }
    
    // Generate metadata XML
    $metaBuilder = new SimpleSAML\Metadata\SAMLBuilder($entityId);
    $metaBuilder->addMetadata('saml20-sp-hosted', $metadata);
    $xml = $metaBuilder->getEntityDescriptor();
    
    echo $xml;
    
} catch (Exception $e) {
    http_response_code(404);
    echo 'Error: ' . htmlspecialchars($e->getMessage());
}
