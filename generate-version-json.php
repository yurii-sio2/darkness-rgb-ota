<?php

function getFileList($directory) {
	$excludeFileNames = [
		'file-list.json',
		'generate-version-json.php'
	];

	$files = [];

	// Open directory
	if ($handle = opendir($directory)) {
		while (false !== ($entry = readdir($handle))) {
			if (!is_dir("$directory/$entry") && !in_array($entry, $excludeFileNames)) {
				$files[] = $entry;
			}
		}
		closedir($handle);
	}

	return $files;
}

function getFileSizes($files, $directory) {
	$fileDetails = [];

	foreach ($files as $file) {
		$filePath = "$directory/$file";
		if (is_file($filePath)) {
			$size = filesize($filePath);
			$fileDetails[] = ['name' => $file, 'size' => $size];
		}
	}

	return $fileDetails;
}

function saveToFileListJson($fileDetails) {
	$jsonContent = json_encode([
		'version' => time(),
		'fileList' => $fileDetails
	], JSON_PRETTY_PRINT);

	if (file_put_contents('file-list.json', $jsonContent)) {
		echo "File list saved to file-list.json\n";
	} else {
		echo "Failed to save file list\n";
	}
}

function generateAndSaveFileList() {
	$directory = __DIR__; // Current directory
	$files = getFileList($directory);
	$fileDetails = getFileSizes($files, $directory);
	saveToFileListJson($fileDetails);
}

generateAndSaveFileList();
