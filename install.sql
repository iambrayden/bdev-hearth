-- Optional: the resource creates these tables automatically on start.

CREATE TABLE IF NOT EXISTS `bdev_hearth_circles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(48) NOT NULL,
    `invite_code` VARCHAR(12) NOT NULL,
    `owner` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `invite_code` (`invite_code`)
);

CREATE TABLE IF NOT EXISTS `bdev_hearth_members` (
    `circle_id` INT UNSIGNED NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `role` VARCHAR(10) NOT NULL DEFAULT 'member',
    `sharing` TINYINT(1) NOT NULL DEFAULT 1,
    `notify` TINYINT(1) NOT NULL DEFAULT 1,
    `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`circle_id`, `citizenid`),
    KEY `citizenid` (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `bdev_hearth_places` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `circle_id` INT UNSIGNED NOT NULL,
    `name` VARCHAR(32) NOT NULL,
    `icon` VARCHAR(16) NOT NULL DEFAULT 'star',
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL DEFAULT 0,
    `radius` FLOAT NOT NULL,
    `created_by` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `circle_id` (`circle_id`)
);

CREATE TABLE IF NOT EXISTS `bdev_hearth_events` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `circle_id` INT UNSIGNED NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `kind` VARCHAR(20) NOT NULL,
    `place` VARCHAR(32) DEFAULT NULL,
    `message` VARCHAR(160) DEFAULT NULL,
    `x` FLOAT DEFAULT NULL,
    `y` FLOAT DEFAULT NULL,
    `created_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `circle_id` (`circle_id`, `id`)
);

CREATE TABLE IF NOT EXISTS `bdev_hearth_lastseen` (
    `citizenid` VARCHAR(50) NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `street` VARCHAR(80) DEFAULT NULL,
    `zone` VARCHAR(80) DEFAULT NULL,
    `updated_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`citizenid`)
);
