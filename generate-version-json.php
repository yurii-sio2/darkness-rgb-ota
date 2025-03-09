<?php

function getFileListAndRename($directory) {
	$excludeFileNames = [
		'file-list.json',
		'generate-version-json.php',
		'process-files.bat',
	];

	$files = [];

	// Open directory
	if ($handle = opendir($directory)) {
		while (false !== ($entry = readdir($handle))) {
			$entryNew = str_replace('a_', '', $entry);
			if (!is_dir("$directory/$entry") && !in_array($entry, $excludeFileNames)) {
				rename($entry, $entryNew);
				$files[] = $entryNew;
			}
		}
		closedir($handle);
	}

	return array_unique($files);
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

function cleanConfigFile($filePath) {
	if (!file_exists($filePath)) {
		echo "File not found!";
		return;
	}

	$content = file_get_contents($filePath);
	$lines = explode("\n", $content);

	foreach ($lines as &$line) {
		// Check if the line contains 'wifiCnf.pwd' or 'wifiCnf.ssid'
		if (strpos($line, 'wifiCnf.pwd') !== false || strpos($line, 'wifiCnf.ssid') !== false) {
			// Remove characters between quotes, keeping the quotes
			$line = preg_replace('/"([^"]*)"/', '""', $line);
			// echo $line . "\n";
		}
	}

	$cleanedContent = implode("\n", $lines);

	if (file_put_contents($filePath, $cleanedContent)) {
		echo "File updated successfully!";
	} else {
		echo "Failed to write to file!";
	}
}


function generateAndSaveFileList() {
	$directory = __DIR__; // Current directory
	$files = getFileListAndRename($directory);
	
	cleanConfigFile('config.lua');
	
	$fileDetails = getFileSizes($files, $directory);
	saveToFileListJson($fileDetails);
}

generateAndSaveFileList();
